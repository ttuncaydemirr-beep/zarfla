'use strict';

// Zarfla — gizlilik dostu günlük istatistik (yalnız sunucu; istemcide SDK yok, kural: stats/** istemciye tamamen kapalı).
// Çıktı yalnız SAYILARDIR: kişisel veri, uid, isim, telefon, jeton, davetiye kimliği, ham zaman damgası yazılmaz.
// Kaynaklar: invites (yalnız yayınlanmış davetiyeler Firestore'da durur; taslaklar cihazdadır) ve purchases.
// Çıktı belgesi: stats/daily/days/{yyyy-mm-dd}  (gün sınırı: Europe/Istanbul, UTC+3 sabit; Türkiye 2016'dan beri yaz saati uygulamıyor).

const INVITES = 'invites';
const PURCHASES = 'purchases';
const H = 3600 * 1000;
const TZ_OFFSET_MS = 3 * H;
const DAY_MS = 24 * H;

/** Davetiye belgesi okurken sayfa boyu: data alanı 200 KB'a kadar olabilir → bellek için küçük sayfa. */
const PAGE_SIZE = 200;
/** Bir boyutta (tür, tasarım...) en çok bu kadar farklı anahtar; fazlası "other" (istemci metnine bağlı anahtar patlamasına karşı). */
const MAX_KEYS = 40;
const LANGS = new Set(['tr', 'en', 'de', 'ar', 'es', 'pt', 'id']);
const PLANS = new Set(['free', 'paid']);
const TOKEN_RE = /^[a-z0-9_-]{1,40}$/;
const DAY_RE = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;

/** Epoch ms → İstanbul takvim günü "yyyy-mm-dd". */
function istanbulDay(ms) {
  return new Date(ms + TZ_OFFSET_MS).toISOString().slice(0, 10);
}

/** "yyyy-mm-dd" (İstanbul günü) → [startMs, endMs) (UTC epoch). Geçersiz gün için hata fırlatır. */
function dayRange(day) {
  if (typeof day !== 'string' || !DAY_RE.test(day)) throw new Error('bad-day');
  const [y, m, d] = day.split('-').map(Number);
  const startMs = Date.UTC(y, m - 1, d) - TZ_OFFSET_MS;
  if (!Number.isFinite(startMs) || istanbulDay(startMs) !== day) throw new Error('bad-day');
  return { startMs, endMs: startMs + DAY_MS };
}

/** Önceki İstanbul günü (günlük çalışma dünü özetler). */
function previousDay(nowMs) {
  return istanbulDay(nowMs - DAY_MS);
}

function cleanToken(v) {
  return typeof v === 'string' && TOKEN_RE.test(v) ? v : 'other';
}

/** Sayacı artırır; yeni anahtar sınırı aşarsa "other". */
function bump(map, key) {
  let k = key;
  if (!(k in map) && Object.keys(map).length >= MAX_KEYS) k = 'other';
  map[k] = (map[k] || 0) + 1;
}

/** data JSON'undan YALNIZ lang/layout/opening alınır (geri kalan, isimler dahil, hiç saklanmaz). */
function inviteTraits(dataStr) {
  const out = { lang: 'other', layout: 'other', opening: 'other' };
  if (typeof dataStr !== 'string') return out;
  let o;
  try {
    o = JSON.parse(dataStr);
  } catch (_) {
    return out;
  }
  if (!o || typeof o !== 'object') return out;
  if (typeof o.lang === 'string' && LANGS.has(o.lang)) out.lang = o.lang;
  out.layout = cleanToken(o.layout);
  out.opening = cleanToken(o.opening);
  return out;
}

/** invites belgelerinden (düz nesneler) sayımlar. */
function aggregateInvites(docs) {
  const r = { created: 0, published: 0, byType: {}, byTheme: {}, byOpening: {}, byLayout: {}, byLanguage: {}, byPlan: {} };
  for (const d of docs) {
    if (!d || typeof d !== 'object') continue;
    r.created++;
    if (d.status === 'live') r.published++;
    bump(r.byType, cleanToken(d.type));
    bump(r.byTheme, cleanToken(d.theme));
    bump(r.byPlan, PLANS.has(d.plan) ? d.plan : 'other');
    const t = inviteTraits(d.data);
    bump(r.byLanguage, t.lang);
    bump(r.byLayout, t.layout);
    bump(r.byOpening, t.opening);
  }
  return r;
}

/** purchases belgelerinden sayımlar (iade edilenler ayrıca sayılır; belge kimliği/jeton/uid okunmaz). */
function aggregatePurchases(docs) {
  const r = { granted: 0, byProduct: {}, upgrades: 0, voided: 0 };
  for (const d of docs) {
    if (!d || typeof d !== 'object') continue;
    r.granted++;
    bump(r.byProduct, cleanToken(d.productId));
    if (d.upgrade === true) r.upgrades++;
    if (d.voided === true) r.voided++;
  }
  return r;
}

/** Tek alanda aralık sorgusu, sayfalı. Yalnız [fields] alanları okunur. */
async function fetchRange(db, collection, field, startTs, endTs, fields) {
  const out = [];
  let last = null;
  for (;;) {
    let q = db.collection(collection).where(field, '>=', startTs).where(field, '<', endTs).orderBy(field).select(...fields).limit(PAGE_SIZE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    for (const doc of snap.docs) out.push(doc.data());
    if (snap.docs.length < PAGE_SIZE) break;
    last = snap.docs[snap.docs.length - 1];
  }
  return out;
}

/**
 * dailyStats: [opts.day] (varsayılan: dün, İstanbul) gününün sayımlarını stats/daily/days/{gün} belgesine yazar.
 * Yeniden çalıştırmak aynı belgeyi aynı sayılarla ezer (idempotent).
 */
async function dailyStats(deps, opts = {}) {
  const { db, fv, now, log } = deps;
  const day = opts.day || previousDay(now());
  const { startMs, endMs } = dayRange(day);
  const startTs = fv.ts(startMs);
  const endTs = fv.ts(endMs);
  const invites = await fetchRange(db, INVITES, 'createdAt', startTs, endTs, ['plan', 'status', 'type', 'theme', 'data']);
  const purchases = await fetchRange(db, PURCHASES, 'grantedAt', startTs, endTs, ['productId', 'upgrade', 'voided']);
  const doc = {
    schema: 1,
    day,
    tz: 'Europe/Istanbul',
    generatedAt: fv.serverTimestamp(),
    invitations: aggregateInvites(invites),
    purchases: aggregatePurchases(purchases),
  };
  await db.collection('stats').doc('daily').collection('days').doc(day).set(doc);
  log.info('daily stats written', { day, invitations: doc.invitations.created, purchases: doc.purchases.granted });
  return doc;
}

module.exports = {
  PAGE_SIZE,
  MAX_KEYS,
  istanbulDay,
  dayRange,
  previousDay,
  inviteTraits,
  aggregateInvites,
  aggregatePurchases,
  fetchRange,
  dailyStats,
};
