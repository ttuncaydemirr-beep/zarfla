'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const L = require('../src/logic');
const S = require('../src/services');
const { FakeDb, Ts, fakePublisher, makeDeps } = require('./fakes');

const ID = 'AbCdEf123456';
const TOKEN = 'tok-1234567890-abcdef';
const NOW = Date.UTC(2026, 10, 15, 12, 0, 0);
const D = 24 * 3600 * 1000;

// Dart Invitation.toInviteData() anahtar sırası (rules-test/rules.test.mjs ile aynı)
function dataJson(o = {}) {
  return JSON.stringify({
    id: o.id ?? 'yerel-id',
    type: o.type ?? 'dugun',
    theme: o.theme ?? 'altin',
    lang: 'tr',
    layout: 'klasik',
    opening: 'door',
    n1: o.n1 ?? 'Test A',
    n2: o.n2 ?? 'Test B',
    host: '',
    msg: o.msg ?? 'Sizi aramızda görmek isteriz.',
    date: o.date ?? '2027-06-12',
    time: '19:00',
    end: '',
    venue: 'Test Venue',
    address: '',
    wa: '',
    program: [{ t: '19:00', x: 'Karşılama' }],
    notes: o.notes ?? [],
    cover: '',
    photos: [],
    status: o.status ?? 'draft',
    plan: o.plan ?? 'premium',
    ...(o.extra ?? {}),
  });
}

const purchased = (o = {}) => ({ purchaseState: 0, consumptionState: 0, acknowledgementState: 0, orderId: 'GPA.1', purchaseTimeMillis: String(NOW - 1000), ...o });
const input = (o = {}) => ({ inviteId: ID, purchaseToken: TOKEN, productId: 'zarfla_invite_1', data: dataJson(), ...o });

describe('logic', () => {
  test('buildPaidData: anahtar sırası, plan premium, status live, kilitler, kural uyumu', () => {
    const { data, lock } = L.buildPaidData(dataJson({ n1: 'Ay"şe\\x' }), ID);
    assert.ok(data.startsWith(`{"id":"${ID}","type":"dugun","theme":"altin",`));
    const o = JSON.parse(data);
    assert.equal(o.plan, 'premium');
    assert.equal(o.status, 'live');
    assert.equal(o.n1, 'Ayşex');
    assert.deepEqual(lock, { type: 'dugun', theme: 'altin', n1: 'Ayşex', n2: 'Test B', date: '2027-06-12', origDate: '2027-06-12', nameEdits: 0, dateEdits: 0 });
    assert.ok(L.ruleDataOk(data, { ...lock, plan: 'paid' }, ID));
    assert.equal(L.ruleDataOk(data, { ...lock, plan: 'free' }, ID), false);
  });

  test('buildPaidData: geçersiz veri reddedilir', () => {
    const bad = (s) => assert.throws(() => L.buildPaidData(s, ID), (e) => e instanceof L.RedeemError && e.code === 'invalid-argument');
    bad('not json');
    bad('[]');
    bad(dataJson({ type: 'Dugun' }));
    bad(dataJson({ theme: 'a-b' }));
    bad(dataJson({ date: '' }));
    bad(dataJson({ msg: 'x'.repeat(200001) }));
    // iç içe nesnede kilit anahtarı → kuraldaki "once" bozulur → ret
    bad(dataJson({ extra: { x: { theme: 'papatya' } } }));
  });

  test('checkProductPurchase', () => {
    assert.equal(L.checkProductPurchase(purchased()), null);
    assert.equal(L.checkProductPurchase(purchased({ purchaseState: 2 })), 'pending');
    assert.equal(L.checkProductPurchase(purchased({ purchaseState: 1 })), 'not-purchased');
    assert.equal(L.checkProductPurchase(purchased({ consumptionState: 1 })), 'consumed');
    assert.equal(L.checkProductPurchase(purchased({ productId: 'other' })), 'bad-product');
    assert.equal(L.checkProductPurchase(null), 'not-purchased');
  });

  test('parseRedeemInput', () => {
    assert.throws(() => L.parseRedeemInput({ ...input(), productId: 'x' }), /bad-product/);
    assert.throws(() => L.parseRedeemInput({ ...input(), purchaseToken: 'k' }), /bad-token/);
    assert.throws(() => L.parseRedeemInput({ ...input(), inviteId: 'short' }), /bad-invite-id/);
    assert.equal(L.parseRedeemInput({ purchaseToken: TOKEN, productId: 'zarfla_invite_1' }).inviteId, null);
  });

  test('süreler: ücretli +365 gün, deleteAt +395 gün; iade en geç +24 saat', () => {
    const t = L.paidTimes(NOW);
    assert.equal(t.expiresAtMs, NOW + 365 * D);
    assert.equal(t.deleteAtMs, NOW + 395 * D);
    assert.equal(L.voidedTimes(NOW + 300 * D, NOW).expiresAtMs, NOW + D);
    assert.equal(L.voidedTimes(NOW + 3600 * 1000, NOW).expiresAtMs, NOW + 3600 * 1000);
  });

  test('ücretsiz sınır kararı', () => {
    const newDoc = { id: 'N', plan: 'free', createdAt: new Ts(NOW) };
    const older = { id: 'O', plan: 'free', createdAt: new Ts(NOW - 3600e3), expiresAt: new Ts(NOW + 20 * 3600e3) };
    assert.equal(L.shouldRevokeFree(newDoc, [older, newDoc], NOW), true);
    assert.equal(L.shouldRevokeFree(newDoc, [{ ...older, expiresAt: new Ts(NOW + 5 * 60e3) }], NOW), false, 'tolerans içinde bitiyor');
    assert.equal(L.shouldRevokeFree(newDoc, [{ ...older, plan: 'paid' }], NOW), false);
    assert.equal(L.shouldRevokeFree({ ...newDoc, plan: 'paid' }, [older], NOW), false);
    assert.equal(L.shouldRevokeFree(newDoc, [{ ...older, createdAt: new Ts(NOW + 1) }], NOW), false, 'daha yenisi sayılmaz');
  });

  test('storage gruplama ve bayatlık', () => {
    const g = L.groupFilesByInvite([`invites/${ID}/cover.jpg`, `invites/${ID}/g1.webp`, 'invites/bad/x.jpg', 'other/a']);
    assert.deepEqual([...g.keys()], [ID]);
    assert.equal(g.get(ID).length, 2);
    assert.equal(L.isStaleInvite(false, null, NOW), true);
    assert.equal(L.isStaleInvite(true, { deleteAt: new Ts(NOW - 1) }, NOW), true);
    assert.equal(L.isStaleInvite(true, { deleteAt: new Ts(NOW + 1) }, NOW), false);
  });
});

describe('redeem (sahte Play API)', () => {
  test('geçerli satın alma: davetiye ücretli yazılır, kayıt, premium, onay', async () => {
    const pub = fakePublisher({ [TOKEN]: purchased() });
    const deps = makeDeps({ publisher: pub, now: () => NOW });
    const r = await S.redeem(deps, 'alice', input());
    assert.equal(r.ok, true);
    assert.equal(r.alreadyGranted, false);
    assert.equal(r.expiresAt, NOW + 365 * D);
    const inv = deps.db.data('invites', ID);
    assert.equal(inv.plan, 'paid');
    assert.equal(inv.ownerUid, 'alice');
    assert.equal(inv.expiresAt.toMillis(), NOW + 365 * D);
    assert.equal(inv.deleteAt.toMillis(), NOW + 395 * D);
    assert.equal(inv.theme, 'altin');
    assert.equal(inv.nameEdits, 0);
    assert.equal(inv.origDate, inv.date);
    assert.ok(L.ruleDataOk(inv.data, inv, ID));
    const rec = deps.db.data('purchases', L.sha256(TOKEN));
    assert.equal(rec.uid, 'alice');
    assert.equal(rec.inviteId, ID);
    assert.equal(rec.orderId, 'GPA.1');
    assert.equal(rec.voided, false);
    assert.equal(JSON.stringify(rec).includes(TOKEN), false, 'ham jeton saklanmaz');
    assert.equal(deps.db.data('users', 'alice').premium, true);
    assert.equal(pub.calls.ack, 1);
  });

  test('idempotent: aynı jeton + aynı davetiye tekrar başarı, Play yeniden çağrılmaz', async () => {
    const pub = fakePublisher({ [TOKEN]: purchased() });
    const deps = makeDeps({ publisher: pub, now: () => NOW });
    await S.redeem(deps, 'alice', input());
    const r = await S.redeem(deps, 'alice', input());
    assert.equal(r.ok, true);
    assert.equal(r.alreadyGranted, true);
    assert.equal(r.expiresAt, NOW + 365 * D);
    assert.equal(pub.calls.get, 1);
  });

  test('aynı jeton başka davetiye / başka kullanıcı: token-used', async () => {
    const deps = makeDeps({ publisher: fakePublisher({ [TOKEN]: purchased() }), now: () => NOW });
    await S.redeem(deps, 'alice', input());
    await assert.rejects(S.redeem(deps, 'alice', input({ inviteId: 'ZZZZZZ123456' })), (e) => e.code === 'already-exists' && e.reason === 'token-used');
    await assert.rejects(S.redeem(deps, 'bob', input()), (e) => e.reason === 'token-used');
  });

  test('davetiyesiz çağrı: verilmişse alreadyGranted, verilmemişse needs-invite', async () => {
    const deps = makeDeps({ publisher: fakePublisher({ [TOKEN]: purchased() }), now: () => NOW });
    await assert.rejects(S.redeem(deps, 'alice', { purchaseToken: TOKEN, productId: 'zarfla_invite_1' }), (e) => e.reason === 'needs-invite');
    await S.redeem(deps, 'alice', input());
    const r = await S.redeem(deps, 'carol', { purchaseToken: TOKEN, productId: 'zarfla_invite_1' });
    assert.equal(r.alreadyGranted, true);
    assert.equal(r.sameInvite, false);
  });

  test('beklemede / iptal / tüketilmiş / geçersiz jeton / Play yetki hatası', async () => {
    const pub = fakePublisher({
      pend00000001: purchased({ purchaseState: 2 }),
      canc00000001: purchased({ purchaseState: 1 }),
      cons00000001: purchased({ consumptionState: 1 }),
      auth00000001: { __throw: 403 },
      down00000001: { __throw: 503 },
    });
    const deps = makeDeps({ publisher: pub, now: () => NOW });
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'pend00000001' })), (e) => e.code === 'failed-precondition' && e.reason === 'pending');
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'canc00000001' })), (e) => e.reason === 'not-purchased');
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'cons00000001' })), (e) => e.reason === 'consumed');
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'none00000001' })), (e) => e.code === 'invalid-argument' && e.reason === 'invalid-token');
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'auth00000001' })), (e) => e.code === 'internal' && e.reason === 'publisher-auth');
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'down00000001' })), (e) => e.code === 'unavailable');
    assert.equal(deps.db.data('invites', ID), undefined);
  });

  test('ücretsizden yükseltme: sahibi aynıysa createdAt korunur; başkasının belgesi ve zaten ücretli belge ret', async () => {
    const db = new FakeDb();
    db.put('invites', ID, { ownerUid: 'alice', plan: 'free', createdAt: new Ts(NOW - 3600e3) });
    const deps = makeDeps({ db, publisher: fakePublisher({ [TOKEN]: purchased(), tok2xxxxxxxx: purchased() }), now: () => NOW });
    await assert.rejects(S.redeem(deps, 'bob', input()), (e) => e.code === 'permission-denied');
    await S.redeem(deps, 'alice', input());
    assert.equal(db.data('invites', ID).createdAt.toMillis(), NOW - 3600e3);
    assert.equal(db.data('invites', ID).plan, 'paid');
    await assert.rejects(S.redeem(deps, 'alice', input({ purchaseToken: 'tok2xxxxxxxx' })), (e) => e.reason === 'already-paid');
  });

  test('onaylanmış alım yeniden onaylanmaz; oturumsuz ret', async () => {
    const pub = fakePublisher({ [TOKEN]: purchased({ acknowledgementState: 1 }) });
    const deps = makeDeps({ publisher: pub, now: () => NOW });
    await S.redeem(deps, 'alice', input());
    assert.equal(pub.calls.ack, 0);
    await assert.rejects(S.redeem(deps, null, input()), (e) => e.code === 'unauthenticated');
  });
});

describe('voided / ücretsiz sınır / storage', () => {
  test('iade: alım voided, davetiye en geç 24 saatte kapanır, premium yeniden hesaplanır, idempotent', async () => {
    const pub = fakePublisher({ [TOKEN]: purchased(), tok2xxxxxxxx: purchased() }, [
      { purchaseToken: TOKEN, voidedTimeMillis: String(NOW), voidedSource: 1, voidedReason: 1 },
      { purchaseToken: 'unknown-token-xyz' },
    ]);
    const deps = makeDeps({ publisher: pub, now: () => NOW });
    await S.redeem(deps, 'alice', input());
    const r = await S.processVoided(deps);
    assert.deepEqual(r, { seen: 2, applied: 1 });
    const inv = deps.db.data('invites', ID);
    assert.equal(inv.expiresAt.toMillis(), NOW + D);
    assert.equal(inv.deleteAt.toMillis(), NOW + 31 * D);
    assert.equal(inv.plan, 'paid');
    assert.equal(deps.db.data('purchases', L.sha256(TOKEN)).voided, true);
    assert.equal(deps.db.data('users', 'alice').premium, false);
    assert.deepEqual(await S.processVoided(deps), { seen: 2, applied: 0 });
    await assert.rejects(S.redeem(deps, 'alice', input()), (e) => e.reason === 'voided');
  });

  test('iade sonrası başka geçerli alım varsa premium kalır', async () => {
    const pub = fakePublisher({ [TOKEN]: purchased(), tok2xxxxxxxx: purchased() }, [{ purchaseToken: TOKEN }]);
    const deps = makeDeps({ publisher: pub, now: () => NOW });
    await S.redeem(deps, 'alice', input());
    await S.redeem(deps, 'alice', input({ inviteId: 'BBBBBB123456', purchaseToken: 'tok2xxxxxxxx' }));
    await S.processVoided(deps);
    assert.equal(deps.db.data('users', 'alice').premium, true);
  });

  test('enforceFreeLimit: ikinci açık ücretsiz davetiye kapanır, ilk dokunulmaz', async () => {
    const db = new FakeDb();
    db.put('invites', 'OLDOLD123456', { ownerUid: 'alice', plan: 'free', createdAt: new Ts(NOW - 3600e3), expiresAt: new Ts(NOW + 23 * 3600e3) });
    const fresh = { ownerUid: 'alice', plan: 'free', createdAt: new Ts(NOW), expiresAt: new Ts(NOW + D) };
    db.put('invites', 'NEWNEW123456', fresh);
    const deps = makeDeps({ db, now: () => NOW });
    assert.equal(await S.enforceFreeLimit(deps, 'NEWNEW123456', fresh), true);
    assert.equal(db.data('invites', 'NEWNEW123456').expiresAt.toMillis(), NOW);
    assert.equal(db.data('invites', 'OLDOLD123456').expiresAt.toMillis(), NOW + 23 * 3600e3);
    // tek ücretsiz → dokunulmaz
    const db2 = new FakeDb();
    db2.put('invites', 'NEWNEW123456', fresh);
    assert.equal(await S.enforceFreeLimit(makeDeps({ db: db2, now: () => NOW }), 'NEWNEW123456', fresh), false);
  });

  test('cleanupStorage: belgesi olmayan / deleteAt geçmiş dosyalar silinir, yeni ve canlılar kalır', async () => {
    const db = new FakeDb();
    db.put('invites', 'LIVELIVE1234', { deleteAt: new Ts(NOW + D) });
    db.put('invites', 'PASTPAST1234', { deleteAt: new Ts(NOW - D) });
    const old = new Date(NOW - 2 * D).toISOString();
    const recent = new Date(NOW - 60e3).toISOString();
    const deleted = [];
    const mk = (name, t) => ({ name, metadata: { timeCreated: t }, delete: async () => deleted.push(name) });
    const files = [
      mk('invites/LIVELIVE1234/cover.jpg', old),
      mk('invites/PASTPAST1234/g1.jpg', old),
      mk('invites/GONEGONE1234/cover.jpg', old),
      mk('invites/GONEGONE1234/g2.png', recent),
    ];
    const bucket = { getFiles: async () => [files, null] };
    const r = await S.cleanupStorage(makeDeps({ db, bucket, now: () => NOW }));
    assert.equal(r.deleted, 2);
    assert.deepEqual(deleted.sort(), ['invites/GONEGONE1234/cover.jpg', 'invites/PASTPAST1234/g1.jpg']);
  });
});
