'use strict';

// Zarfla — fonksiyon iş akışları. Bağımlılıklar dışarıdan verilir (deps), böylece birim testlerde
// sahte Firestore ve sahte Google Play Developer API (Android Publisher) ile çalıştırılır.
//
// deps = {
//   db,                    // firebase-admin Firestore (ya da test sahtesi)
//   fv: { serverTimestamp(), ts(ms) },
//   publisher: { getProduct(productId, token), acknowledge(productId, token), listVoided({ startTimeMs, pageToken }) },
//   bucket,                // @google-cloud/storage Bucket (yalnız cleanupStorage)
//   now(),                 // ms
//   log: { info, warn, error },
// }

const L = require('./logic');

const INVITES = 'invites';
const PURCHASES = 'purchases';
const USERS = 'users';
const CREDITS = 'credits';

function publisherError(err) {
  const status = Number((err && (err.code || (err.response && err.response.status))) || 0);
  if (status === 400 || status === 404 || status === 410) return new L.RedeemError('invalid-argument', 'invalid-token');
  if (status === 401 || status === 403) return new L.RedeemError('internal', 'publisher-auth');
  return new L.RedeemError('unavailable', 'publisher-unavailable');
}

async function grantedResponse(db, rec, inviteId) {
  const snap = await db.collection(INVITES).doc(inviteId).get();
  const exp = snap.exists ? L.toMs(snap.data().expiresAt) : null;
  return { ok: true, inviteId, expiresAt: exp, alreadyGranted: true, premium: true, orderId: rec.orderId || null };
}

/**
 * redeemPurchase: satın alma jetonunu Google Play'de doğrular, davetiyeyi ücretli yazar.
 * Aynı jeton + aynı davetiye + aynı kullanıcı → yine başarı (idempotent; istemci tüketmeden çökerse).
 * inviteId yoksa: jeton daha önce hak verdiyse { alreadyGranted } (istemci tüketir), yoksa 'needs-invite'.
 */
async function redeem(deps, uid, rawInput) {
  const { db, fv, publisher, now, log } = deps;
  if (!uid) throw new L.RedeemError('unauthenticated', 'no-auth');
  const input = L.parseRedeemInput(rawInput);
  if (L.isBundle(input.productId)) return redeemBundle(deps, uid, input);
  const hash = L.sha256(input.purchaseToken);
  const pRef = db.collection(PURCHASES).doc(hash);

  const pre = await pRef.get();
  if (pre.exists) {
    const rec = pre.data();
    if (rec.voided) throw new L.RedeemError('failed-precondition', 'voided');
    if (input.inviteId === null) {
      return { ok: true, inviteId: rec.inviteId, expiresAt: null, alreadyGranted: true, premium: true, sameInvite: false };
    }
    if (rec.uid === uid && rec.inviteId === input.inviteId) {
      return { ...(await grantedResponse(db, rec, input.inviteId)), sameInvite: true };
    }
    throw new L.RedeemError('already-exists', 'token-used');
  }
  if (input.inviteId === null) throw new L.RedeemError('failed-precondition', 'needs-invite');

  // Ucuz denetimler önce (veri biçimi), sonra Google Play.
  const built = L.buildPaidData(input.data, input.inviteId);

  let purchase;
  try {
    purchase = await publisher.getProduct(input.productId, input.purchaseToken);
  } catch (e) {
    const err = publisherError(e);
    (err.reason === 'publisher-auth' ? log.error : log.warn)('purchases.products.get failed', { status: e && e.code, reason: err.reason });
    throw err;
  }
  const bad = L.checkProductPurchase(purchase, input.productId);
  if (bad) throw new L.RedeemError('failed-precondition', bad);
  // Uygulama satın alırken anonim uid'i obfuscatedAccountId olarak gönderir.
  if (purchase.obfuscatedExternalAccountId && purchase.obfuscatedExternalAccountId !== uid) {
    // Zorlamıyoruz (yeniden kurulumda anonim uid değişir); yalnız kayda geçer.
    log.warn('obfuscatedExternalAccountId mismatch', { inviteId: input.inviteId });
  }

  const nowMs = now();
  const { expiresAtMs, deleteAtMs } = L.paidTimes(nowMs);
  const iRef = db.collection(INVITES).doc(input.inviteId);
  const uRef = db.collection(USERS).doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const p2 = await tx.get(pRef);
    const inv = await tx.get(iRef);
    if (p2.exists) {
      const rec = p2.data();
      if (rec.voided) throw new L.RedeemError('failed-precondition', 'voided');
      if (rec.uid === uid && rec.inviteId === input.inviteId) {
        return { granted: false, expiresAt: inv.exists ? L.toMs(inv.data().expiresAt) : null };
      }
      throw new L.RedeemError('already-exists', 'token-used');
    }
    let createdAt = fv.serverTimestamp();
    if (inv.exists) {
      const cur = inv.data();
      if (cur.ownerUid !== uid) throw new L.RedeemError('permission-denied', 'not-owner');
      if (cur.plan === 'paid') throw new L.RedeemError('failed-precondition', 'already-paid');
      if (cur.createdAt) createdAt = cur.createdAt; // ücretsizden yükseltme: oluşturma anı korunur
    }
    tx.set(iRef, {
      ownerUid: uid,
      schema: 1,
      data: built.data,
      plan: 'paid',
      status: 'live',
      createdAt,
      expiresAt: fv.ts(expiresAtMs),
      deleteAt: fv.ts(deleteAtMs),
      ...built.lock,
    });
    tx.set(pRef, {
      uid,
      inviteId: input.inviteId,
      productId: input.productId,
      orderId: purchase.orderId || null,
      purchaseTimeMillis: purchase.purchaseTimeMillis ? Number(purchase.purchaseTimeMillis) : null,
      purchaseType: purchase.purchaseType == null ? null : purchase.purchaseType, // 0 = test (lisans test kullanıcısı)
      regionCode: purchase.regionCode || null,
      grantedAt: fv.serverTimestamp(),
      upgrade: inv.exists,
      voided: false,
    });
    tx.set(uRef, { premium: true, updatedAt: fv.serverTimestamp() }, { merge: true });
    return { granted: true, expiresAt: expiresAtMs };
  });

  // Onay (acknowledge): 3 gün içinde yapılmazsa Google otomatik iade eder. İstemcinin tüketmesi de onaylar;
  // burada ayrıca yapılır ki istemci tüketmeden kapanırsa ödeme iade olmasın. Hata hak vermeyi bozmaz.
  if (result.granted && purchase.acknowledgementState !== 1) {
    try {
      await publisher.acknowledge(input.productId, input.purchaseToken);
    } catch (e) {
      log.warn('acknowledge failed (client consume will acknowledge)', { status: e && e.code });
    }
  }
  if (result.granted) log.info('purchase granted', { inviteId: input.inviteId, orderId: purchase.orderId || null });
  return {
    ok: true,
    inviteId: input.inviteId,
    expiresAt: result.expiresAt,
    alreadyGranted: !result.granted,
    premium: true,
    sameInvite: true,
  };
}

// ---------------------------------------------------------------------------
// "Düğün Zinciri" paketi (zarfla_invite_3): hak defteri credits/{uid}
// ---------------------------------------------------------------------------

/** Ücretli davetiye belgesi (redeem ile aynı alanlar). */
function paidInviteDoc(fv, uid, built, createdAt, nowMs) {
  const { expiresAtMs, deleteAtMs } = L.paidTimes(nowMs);
  return {
    doc: {
      ownerUid: uid,
      schema: 1,
      data: built.data,
      plan: 'paid',
      status: 'live',
      createdAt,
      expiresAt: fv.ts(expiresAtMs),
      deleteAt: fv.ts(deleteAtMs),
      ...built.lock,
    },
    expiresAtMs,
  };
}

/** Davetiye yazılabilir mi (sahibi aynı, henüz ücretli değil)? Dönen değer: korunacak createdAt. */
function writableCreatedAt(fv, inv, uid) {
  if (!inv.exists) return fv.serverTimestamp();
  const cur = inv.data();
  if (cur.ownerUid !== uid) throw new L.RedeemError('permission-denied', 'not-owner');
  if (cur.plan === 'paid') throw new L.RedeemError('failed-precondition', 'already-paid');
  return cur.createdAt || fv.serverTimestamp();
}

function creditsDoc(fv, credits) {
  return { balance: credits.balance, lots: credits.lots, ledger: credits.ledger, updatedAt: fv.serverTimestamp() };
}

async function readBalance(db, uid) {
  const s = await db.collection(CREDITS).doc(uid).get();
  return s.exists ? L.normCredits(s.data()).balance : 0;
}

/**
 * Paket alımı: jeton Google Play'de BİR kez doğrulanır (purchases/{sha256} kaydı = idempotentlik),
 * 3 hak credits/{uid}'e yazılır. inviteId + data verilirse aynı işlemde 1 hak kullanılıp davetiye ücretli yazılır.
 * Daha önce işlenmiş jeton: aynı kullanıcı → (davetiye varsa) useCredit yolu, yoksa alreadyGranted;
 * başka kullanıcı → davetiyesiz çağrıda alreadyGranted (istemci tüketir), davetiyeli çağrıda token-used.
 * Tüketme istemcide, başarıdan sonra (zarfla_invite_1 ile aynı).
 */
async function redeemBundle(deps, uid, input) {
  const { db, fv, publisher, now, log } = deps;
  const hash = L.sha256(input.purchaseToken);
  const pRef = db.collection(PURCHASES).doc(hash);

  const already = async (rec) => {
    if (rec.voided) throw new L.RedeemError('failed-precondition', 'voided');
    if (rec.uid !== uid) {
      if (input.inviteId === null) {
        return { ok: true, inviteId: null, expiresAt: null, alreadyGranted: true, premium: true, sameInvite: false, credits: await readBalance(db, uid) };
      }
      throw new L.RedeemError('already-exists', 'token-used');
    }
    if (input.inviteId === null) {
      return { ok: true, inviteId: null, expiresAt: null, alreadyGranted: true, premium: true, sameInvite: false, credits: await readBalance(db, uid) };
    }
    const r = await useCredit(deps, uid, { inviteId: input.inviteId, data: input.data });
    return { ...r, alreadyGranted: true };
  };

  const pre = await pRef.get();
  if (pre.exists) return already(pre.data());

  const built = input.inviteId === null ? null : L.buildPaidData(input.data, input.inviteId);

  let purchase;
  try {
    purchase = await publisher.getProduct(input.productId, input.purchaseToken);
  } catch (e) {
    const err = publisherError(e);
    (err.reason === 'publisher-auth' ? log.error : log.warn)('purchases.products.get failed', { status: e && e.code, reason: err.reason });
    throw err;
  }
  const bad = L.checkProductPurchase(purchase, input.productId);
  if (bad) throw new L.RedeemError('failed-precondition', bad);
  if (purchase.obfuscatedExternalAccountId && purchase.obfuscatedExternalAccountId !== uid) {
    log.warn('obfuscatedExternalAccountId mismatch (bundle)');
  }

  const nowMs = now();
  const rights = L.rightsFor(input.productId);
  const cRef = db.collection(CREDITS).doc(uid);
  const iRef = input.inviteId === null ? null : db.collection(INVITES).doc(input.inviteId);
  const uRef = db.collection(USERS).doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const p2 = await tx.get(pRef);
    const c = await tx.get(cRef);
    const inv = iRef ? await tx.get(iRef) : null;
    if (p2.exists) return { raced: p2.data() };
    let credits = L.applyGrant(c.exists ? c.data() : null, { h: hash, productId: input.productId, rights, nowMs });
    let expiresAt = null;
    let invDoc = null;
    if (iRef) {
      const createdAt = writableCreatedAt(fv, inv, uid);
      credits = L.applyUse(credits, { inviteId: input.inviteId, nowMs, preferH: hash }).credits;
      const w = paidInviteDoc(fv, uid, built, createdAt, nowMs);
      invDoc = w.doc;
      expiresAt = w.expiresAtMs;
    }
    if (invDoc) tx.set(iRef, invDoc);
    tx.set(cRef, creditsDoc(fv, credits));
    tx.set(pRef, {
      uid,
      inviteId: null,
      kind: 'bundle',
      rights,
      productId: input.productId,
      orderId: purchase.orderId || null,
      purchaseTimeMillis: purchase.purchaseTimeMillis ? Number(purchase.purchaseTimeMillis) : null,
      purchaseType: purchase.purchaseType == null ? null : purchase.purchaseType,
      regionCode: purchase.regionCode || null,
      grantedAt: fv.serverTimestamp(),
      upgrade: !!(inv && inv.exists),
      voided: false,
    });
    tx.set(uRef, { premium: true, updatedAt: fv.serverTimestamp() }, { merge: true });
    return { expiresAt, balance: credits.balance };
  });
  if (result.raced) return already(result.raced);

  if (purchase.acknowledgementState !== 1) {
    try {
      await publisher.acknowledge(input.productId, input.purchaseToken);
    } catch (e) {
      log.warn('acknowledge failed (client consume will acknowledge)', { status: e && e.code });
    }
  }
  log.info('bundle granted', { rights, orderId: purchase.orderId || null, used: input.inviteId !== null });
  return {
    ok: true,
    inviteId: input.inviteId,
    expiresAt: result.expiresAt,
    alreadyGranted: false,
    premium: true,
    sameInvite: input.inviteId !== null,
    credits: result.balance,
  };
}

/**
 * useCredit: defterden 1 hak düşer ve davetiyeyi AYNI işlemde ücretli yazar (Play'e gidilmez).
 * İdempotent: bu davetiye zaten bir haktan ödendiyse yeniden düşülmez, başarı döner (alreadyGranted).
 * Bakiye yoksa 'no-credit'.
 */
async function useCredit(deps, uid, rawInput) {
  const { db, fv, now, log } = deps;
  if (!uid) throw new L.RedeemError('unauthenticated', 'no-auth');
  const input = L.parseUseCreditInput(rawInput);
  const built = L.buildPaidData(input.data, input.inviteId);
  const nowMs = now();
  const cRef = db.collection(CREDITS).doc(uid);
  const iRef = db.collection(INVITES).doc(input.inviteId);
  const uRef = db.collection(USERS).doc(uid);
  const r = await db.runTransaction(async (tx) => {
    const c = await tx.get(cRef);
    const inv = await tx.get(iRef);
    const cur = c.exists ? c.data() : null;
    if (L.lotForInvite(cur, input.inviteId) && inv.exists && inv.data().ownerUid === uid && inv.data().plan === 'paid') {
      return { granted: false, expiresAt: L.toMs(inv.data().expiresAt), balance: L.normCredits(cur).balance };
    }
    const createdAt = writableCreatedAt(fv, inv, uid);
    const { credits } = L.applyUse(cur, { inviteId: input.inviteId, nowMs });
    const w = paidInviteDoc(fv, uid, built, createdAt, nowMs);
    tx.set(iRef, w.doc);
    tx.set(cRef, creditsDoc(fv, credits));
    tx.set(uRef, { premium: true, updatedAt: fv.serverTimestamp() }, { merge: true });
    return { granted: true, expiresAt: w.expiresAtMs, balance: credits.balance };
  });
  if (r.granted) log.info('credit used', { inviteId: input.inviteId, left: r.balance });
  return {
    ok: true,
    inviteId: input.inviteId,
    expiresAt: r.expiresAt,
    alreadyGranted: !r.granted,
    premium: true,
    sameInvite: true,
    credits: r.balance,
  };
}

/** Kullanıcının iade edilmemiş başka satın alması yoksa premium (reklamsız) bayrağını kaldırır. */
async function recomputePremium(deps, uid) {
  const { db, fv } = deps;
  const q = await db.collection(PURCHASES).where('uid', '==', uid).get();
  const active = q.docs.some((d) => !d.data().voided);
  await db.collection(USERS).doc(uid).set({ premium: active, updatedAt: fv.serverTimestamp() }, { merge: true });
  return active;
}

/**
 * voidedPurchases (günlük): son 30 günün iade/geri ödeme/ters ibraz kayıtlarını işler (idempotent).
 * Seçilen en yumuşak uyumlu yol: davetiye SİLİNMEZ ve hemen kapanmaz; bağlantı en geç 24 saat sonra
 * kapanır (expiresAt = min(mevcut, şimdi+24s), deleteAt +30 gün), satın alma "voided" işaretlenir,
 * kullanıcının başka geçerli alımı yoksa premium (reklamsız) bayrağı kalkar. Plan/tasarım alanlarına
 * dokunulmaz (kurallar ücretsiz planda yalnız papatyaya izin verdiği için plan değişimi belgeyi bozardı).
 *
 * PAKET (zarfla_invite_3) İADE POLİTİKASI: Google Play iadesi paketin tamamı içindir. İade edilen paketin
 * KULLANILMAMIŞ hakları defterden silinir (credits/{uid}.balance düşer, lot "voided"), bu paketin haklarıyla
 * yayınlanmış TÜM davetiyeler tekli iadeyle aynı şekilde en geç 24 saatte kapanır. Başka paketlerin hakları
 * ve tekli alımlarla yayınlanmış davetiyeler etkilenmez.
 */
async function processVoided(deps) {
  const { db, fv, publisher, now, log } = deps;
  const nowMs = now();
  const startTimeMs = nowMs - 30 * 24 * 3600 * 1000 + 60 * 1000;
  let pageToken;
  let seen = 0;
  let applied = 0;
  const touchedUsers = new Set();
  do {
    const page = await publisher.listVoided({ startTimeMs, pageToken });
    const list = (page && page.voidedPurchases) || [];
    for (const v of list) {
      seen++;
      if (!v || !v.purchaseToken) continue;
      const pRef = db.collection(PURCHASES).doc(L.sha256(v.purchaseToken));
      const hash = L.sha256(v.purchaseToken);
      const changed = await db.runTransaction(async (tx) => {
        const p = await tx.get(pRef);
        if (!p.exists || p.data().voided) return null;
        const rec = p.data();
        // Paket: kalan haklar silinir, paketle yayınlanan TÜM davetiyeler (en çok 3) en geç 24 saatte kapanır.
        const bundle = rec.kind === 'bundle' || L.isBundle(rec.productId);
        let cRef = null;
        let voidRes = null;
        let inviteIds = rec.inviteId ? [rec.inviteId] : [];
        if (bundle) {
          cRef = db.collection(CREDITS).doc(rec.uid);
          const c = await tx.get(cRef);
          voidRes = L.applyVoid(c.exists ? c.data() : null, hash, nowMs);
          inviteIds = voidRes.invites;
        }
        const invs = [];
        for (const id of inviteIds) {
          const iRef = db.collection(INVITES).doc(id);
          invs.push([iRef, await tx.get(iRef)]);
        }
        tx.update(pRef, {
          voided: true,
          voidedAt: fv.serverTimestamp(),
          voidedTimeMillis: v.voidedTimeMillis ? Number(v.voidedTimeMillis) : null,
          voidedSource: v.voidedSource == null ? null : v.voidedSource,
          voidedReason: v.voidedReason == null ? null : v.voidedReason,
          ...(bundle ? { creditsRemoved: voidRes.removed } : {}),
        });
        if (bundle) tx.set(cRef, creditsDoc(fv, voidRes.credits));
        for (const [iRef, inv] of invs) {
          if (!inv.exists) continue;
          const cur = inv.data();
          const curExp = L.toMs(cur.expiresAt);
          if (cur.plan === 'paid' && cur.ownerUid === rec.uid && curExp != null) {
            const t = L.voidedTimes(curExp, nowMs);
            tx.update(iRef, { expiresAt: fv.ts(t.expiresAtMs), deleteAt: fv.ts(t.deleteAtMs) });
          }
        }
        return rec.uid;
      });
      if (changed) {
        applied++;
        touchedUsers.add(changed);
      }
    }
    pageToken = page && page.tokenPagination && page.tokenPagination.nextPageToken;
  } while (pageToken);
  for (const uid of touchedUsers) await recomputePremium(deps, uid);
  log.info('voided purchases processed', { seen, applied });
  return { seen, applied };
}

/**
 * enforceFreeLimit (invites/{id} oluşturulunca): kurallar kullanıcının diğer belgelerini sayamaz.
 * Aynı sahibin daha önce açılmış ve hâlâ açık ücretsiz davetiyesi varsa YENİ belge hemen kapatılır
 * (expiresAt = şimdi, deleteAt = +1 gün; status/plan değişmez → sahibi silebilir). Uygulama zaten
 * bunu engellediği için yalnız kuralları doğrudan çağıran kötüye kullanımı etkiler.
 */
async function enforceFreeLimit(deps, id, docData) {
  const { db, fv, now, log } = deps;
  if (!docData || docData.plan !== 'free' || !docData.ownerUid) return false;
  const nowMs = now();
  const q = await db.collection(INVITES).where('ownerUid', '==', docData.ownerUid).get();
  const others = q.docs.map((d) => ({ id: d.id, ...d.data() }));
  if (!L.shouldRevokeFree({ id, ...docData }, others, nowMs)) return false;
  await db.collection(INVITES).doc(id).update({ expiresAt: fv.ts(nowMs), deleteAt: fv.ts(nowMs + 24 * 3600 * 1000) });
  log.warn('free limit: new free invite closed', { id });
  return true;
}

/**
 * cleanupStorage (günlük): Firestore TTL belgeyi siler ama Storage dosyalarını silmez.
 * invites/{id}/* dosyaları: belge yoksa ya da deleteAt geçtiyse silinir. Son 1 saatte yüklenen dosyalara
 * dokunulmaz (yayın sırası: önce belge, sonra dosya — yine de yarış payı).
 */
async function cleanupStorage(deps) {
  const { db, bucket, now, log } = deps;
  const nowMs = now();
  let pageToken;
  let deleted = 0;
  do {
    const [files, next] = await bucket.getFiles({ prefix: 'invites/', maxResults: 1000, autoPaginate: false, pageToken });
    const byName = new Map(files.map((f) => [f.name, f]));
    const groups = L.groupFilesByInvite(files.map((f) => f.name));
    const ids = [...groups.keys()];
    for (let i = 0; i < ids.length; i += 100) {
      const chunk = ids.slice(i, i + 100);
      const snaps = await db.getAll(...chunk.map((id) => db.collection(INVITES).doc(id)));
      for (let j = 0; j < chunk.length; j++) {
        const s = snaps[j];
        if (!L.isStaleInvite(s.exists, s.exists ? s.data() : null, nowMs)) continue;
        for (const name of groups.get(chunk[j])) {
          const f = byName.get(name);
          const created = Date.parse((f.metadata && f.metadata.timeCreated) || '') || 0;
          if (created > nowMs - 3600 * 1000) continue;
          try {
            await f.delete({ ignoreNotFound: true });
            deleted++;
          } catch (e) {
            log.warn('storage delete failed', { name, code: e && e.code });
          }
        }
      }
    }
    pageToken = next && next.pageToken;
  } while (pageToken);
  log.info('storage cleanup done', { deleted });
  return { deleted };
}

module.exports = { redeem, useCredit, processVoided, enforceFreeLimit, cleanupStorage, recomputePremium, publisherError };
