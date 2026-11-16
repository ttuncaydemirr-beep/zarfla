'use strict';

// "Düğün Zinciri" (zarfla_invite_3): hak defteri, idempotentlik, çifte kullanım, iade.

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const L = require('../src/logic');
const S = require('../src/services');
const { FakeDb, Ts, fakePublisher, makeDeps } = require('./fakes');

const NOW = Date.UTC(2026, 10, 17, 12, 0, 0);
const D = 24 * 3600 * 1000;
const BTOKEN = 'bundle-token-1234567890';
const ID1 = 'AAAAAA111111';
const ID2 = 'BBBBBB222222';
const ID3 = 'CCCCCC333333';
const ID4 = 'DDDDDD444444';

function dataJson(o = {}) {
  return JSON.stringify({
    id: 'yerel',
    type: o.type ?? 'dugun',
    theme: o.theme ?? 'altin',
    lang: 'tr',
    n1: 'Test A',
    n2: 'Test B',
    msg: 'Merhaba',
    date: '2027-06-12',
    status: 'draft',
    plan: 'premium',
  });
}

const purchased = (o = {}) => ({ purchaseState: 0, consumptionState: 0, acknowledgementState: 0, orderId: 'GPA.B1', purchaseTimeMillis: String(NOW - 1000), ...o });
const bundleIn = (o = {}) => ({ purchaseToken: BTOKEN, productId: 'zarfla_invite_3', ...o });
const withInvite = (id, o = {}) => bundleIn({ inviteId: id, data: dataJson(), ...o });
const use = (id) => ({ inviteId: id, data: dataJson() });
const credits = (deps, uid) => deps.db.data('credits', uid);

function setup(products = { [BTOKEN]: purchased() }, voided = []) {
  const pub = fakePublisher(products, voided);
  return { pub, deps: makeDeps({ publisher: pub, now: () => NOW }) };
}

describe('defter (saf)', () => {
  test('ürün → hak; ürün kimliği doğrulama', () => {
    assert.equal(L.rightsFor('zarfla_invite_1'), 1);
    assert.equal(L.rightsFor('zarfla_invite_3'), 3);
    assert.equal(L.rightsFor('zarfla_invite_9'), 0);
    assert.equal(L.isBundle('zarfla_invite_3'), true);
    assert.equal(L.isBundle('zarfla_invite_1'), false);
    assert.equal(L.parseRedeemInput(bundleIn()).inviteId, null);
    assert.throws(() => L.parseRedeemInput(bundleIn({ productId: 'zarfla_invite_9' })), /bad-product/);
  });

  test('grant / use (FIFO + tercih) / void; aynı lot iki kez eklenmez', () => {
    let c = L.applyGrant(null, { h: 'a', productId: 'zarfla_invite_3', rights: 3, nowMs: 1 });
    c = L.applyGrant(c, { h: 'a', productId: 'zarfla_invite_3', rights: 3, nowMs: 2 });
    assert.equal(c.balance, 3);
    c = L.applyGrant(c, { h: 'b', productId: 'zarfla_invite_3', rights: 3, nowMs: 3 });
    assert.equal(c.balance, 6);
    let r = L.applyUse(c, { inviteId: 'X', nowMs: 4 });
    assert.equal(r.h, 'a', 'FIFO: en eski lot');
    r = L.applyUse(r.credits, { inviteId: 'Y', nowMs: 5, preferH: 'b' });
    assert.equal(r.h, 'b');
    assert.equal(r.credits.balance, 4);
    assert.equal(L.lotForInvite(r.credits, 'X'), 'a');
    const v = L.applyVoid(r.credits, 'a', 6);
    assert.equal(v.removed, 2);
    assert.deepEqual(v.invites, ['X']);
    assert.equal(v.credits.balance, 2);
    assert.equal(L.applyVoid(v.credits, 'a', 7).removed, 0, 'iki kez iade edilmez');
    assert.deepEqual(v.credits.ledger.map((e) => e.t), ['grant', 'grant', 'use', 'use', 'void']);
    assert.throws(() => L.applyUse({ lots: [] }, { inviteId: 'Z', nowMs: 1 }), (e) => e.reason === 'no-credit');
  });

  test('defter kaydı en çok LEDGER_MAX', () => {
    let c = L.applyGrant(null, { h: 'a', productId: 'zarfla_invite_3', rights: 500, nowMs: 1 });
    for (let i = 0; i < L.LEDGER_MAX + 20; i++) c = L.applyUse(c, { inviteId: 'I' + i, nowMs: i }).credits;
    assert.equal(c.ledger.length, L.LEDGER_MAX);
    assert.equal(c.balance, 500 - L.LEDGER_MAX - 20);
  });
});

describe('paket alımı (redeemPurchase, zarfla_invite_3)', () => {
  test('davetiyesiz: 3 hak, kayıt, premium, onay; ham jeton saklanmaz', async () => {
    const { pub, deps } = setup();
    const r = await S.redeem(deps, 'alice', bundleIn());
    assert.equal(r.ok, true);
    assert.equal(r.alreadyGranted, false);
    assert.equal(r.credits, 3);
    const c = credits(deps, 'alice');
    assert.equal(c.balance, 3);
    assert.equal(c.lots.length, 1);
    assert.equal(c.lots[0].h, L.sha256(BTOKEN));
    const rec = deps.db.data('purchases', L.sha256(BTOKEN));
    assert.equal(rec.kind, 'bundle');
    assert.equal(rec.rights, 3);
    assert.equal(rec.inviteId, null);
    assert.equal(rec.voided, false);
    assert.equal(JSON.stringify(rec).includes(BTOKEN), false);
    assert.equal(JSON.stringify(c).includes(BTOKEN), false);
    assert.equal(deps.db.data('users', 'alice').premium, true);
    assert.equal(pub.calls.ack, 1);
  });

  test('davetiyeli: 3 hak + 1 hemen kullanılır (bakiye 2), davetiye ücretli ve kurala uygun', async () => {
    const { deps } = setup();
    const r = await S.redeem(deps, 'alice', withInvite(ID1));
    assert.equal(r.credits, 2);
    assert.equal(r.expiresAt, NOW + L.PAID_LIFE_MS);
    const inv = deps.db.data('invites', ID1);
    assert.equal(inv.plan, 'paid');
    assert.equal(inv.ownerUid, 'alice');
    assert.ok(L.ruleDataOk(inv.data, inv, ID1));
    assert.deepEqual(credits(deps, 'alice').lots[0].invites, [ID1]);
  });

  test('idempotent: aynı jeton tekrar → Play bir kez, hak bir kez; davetiyeli tekrar düşmez', async () => {
    const { pub, deps } = setup();
    await S.redeem(deps, 'alice', withInvite(ID1));
    const again = await S.redeem(deps, 'alice', withInvite(ID1));
    assert.equal(again.ok, true);
    assert.equal(again.alreadyGranted, true);
    assert.equal(again.credits, 2);
    const plain = await S.redeem(deps, 'alice', bundleIn());
    assert.equal(plain.alreadyGranted, true);
    assert.equal(plain.credits, 2);
    assert.equal(pub.calls.get, 1);
    assert.equal(credits(deps, 'alice').lots.length, 1);
  });

  test('aynı jeton ama yeni davetiye (istemci tüketmeden): defterden hak kullanılır, yeniden kredi verilmez', async () => {
    const { pub, deps } = setup();
    await S.redeem(deps, 'alice', withInvite(ID1));
    const r = await S.redeem(deps, 'alice', withInvite(ID2));
    assert.equal(r.credits, 1);
    assert.equal(deps.db.data('invites', ID2).plan, 'paid');
    assert.equal(pub.calls.get, 1);
  });

  test('başka kullanıcı aynı jeton: davetiyesiz alreadyGranted (kendi bakiyesi), davetiyeli token-used', async () => {
    const { deps } = setup();
    await S.redeem(deps, 'alice', bundleIn());
    const r = await S.redeem(deps, 'bob', bundleIn());
    assert.equal(r.alreadyGranted, true);
    assert.equal(r.credits, 0);
    await assert.rejects(S.redeem(deps, 'bob', withInvite(ID1)), (e) => e.code === 'already-exists' && e.reason === 'token-used');
    assert.equal(credits(deps, 'bob'), undefined);
    assert.equal(credits(deps, 'alice').balance, 3);
  });

  test('beklemede / tüketilmiş / yanlış ürün: hak yok', async () => {
    const { deps } = setup({ pend00000001: purchased({ purchaseState: 2 }), cons00000001: purchased({ consumptionState: 1 }) });
    await assert.rejects(S.redeem(deps, 'alice', bundleIn({ purchaseToken: 'pend00000001' })), (e) => e.reason === 'pending');
    await assert.rejects(S.redeem(deps, 'alice', bundleIn({ purchaseToken: 'cons00000001' })), (e) => e.reason === 'consumed');
    await assert.rejects(S.redeem(deps, 'alice', bundleIn({ purchaseToken: 'none00000001' })), (e) => e.reason === 'invalid-token');
    assert.equal(credits(deps, 'alice'), undefined);
  });

  test('davetiye başkasınınsa işlem bütünüyle geri alınır (kredi de yazılmaz)', async () => {
    const { deps } = setup();
    deps.db.put('invites', ID1, { ownerUid: 'bob', plan: 'free', createdAt: new Ts(NOW - D) });
    await assert.rejects(S.redeem(deps, 'alice', withInvite(ID1)), (e) => e.code === 'permission-denied');
    assert.equal(credits(deps, 'alice'), undefined);
    assert.equal(deps.db.data('purchases', L.sha256(BTOKEN)), undefined);
  });

  test('tekli ürün (zarfla_invite_1) eski akışta: deftere dokunulmaz', async () => {
    const deps = makeDeps({ publisher: fakePublisher({ 'single-token-123456': purchased() }), now: () => NOW });
    const r = await S.redeem(deps, 'alice', { inviteId: ID1, purchaseToken: 'single-token-123456', productId: 'zarfla_invite_1', data: dataJson() });
    assert.equal(r.ok, true);
    assert.equal(r.credits, undefined);
    assert.equal(credits(deps, 'alice'), undefined);
    assert.equal(deps.db.data('purchases', L.sha256('single-token-123456')).inviteId, ID1);
  });
});

describe('useCredit', () => {
  test('3 hak → 3 davetiye; 4. no-credit; Play çağrılmaz', async () => {
    const { pub, deps } = setup();
    await S.redeem(deps, 'alice', bundleIn());
    assert.equal((await S.useCredit(deps, 'alice', use(ID1))).credits, 2);
    assert.equal((await S.useCredit(deps, 'alice', use(ID2))).credits, 1);
    const last = await S.useCredit(deps, 'alice', use(ID3));
    assert.equal(last.credits, 0);
    assert.equal(last.expiresAt, NOW + L.PAID_LIFE_MS);
    await assert.rejects(S.useCredit(deps, 'alice', use(ID4)), (e) => e.code === 'failed-precondition' && e.reason === 'no-credit');
    assert.equal(deps.db.data('invites', ID4), undefined);
    assert.equal(pub.calls.get, 1);
    for (const id of [ID1, ID2, ID3]) assert.equal(deps.db.data('invites', id).plan, 'paid');
  });

  test('çifte kullanım: aynı davetiye için tekrar çağrı hak düşmez (idempotent)', async () => {
    const { deps } = setup();
    await S.redeem(deps, 'alice', bundleIn());
    await S.useCredit(deps, 'alice', use(ID1));
    const r = await S.useCredit(deps, 'alice', use(ID1));
    assert.equal(r.alreadyGranted, true);
    assert.equal(r.credits, 2);
    assert.equal(credits(deps, 'alice').balance, 2);
  });

  test('ücretsizden yükseltme createdAt korunur; zaten ücretli / başkasının belgesi ret; hak düşmez', async () => {
    const { deps } = setup();
    await S.redeem(deps, 'alice', bundleIn());
    deps.db.put('invites', ID1, { ownerUid: 'alice', plan: 'free', createdAt: new Ts(NOW - 2 * D), expiresAt: new Ts(NOW - D) });
    deps.db.put('invites', ID2, { ownerUid: 'alice', plan: 'paid', createdAt: new Ts(NOW - D) });
    deps.db.put('invites', ID3, { ownerUid: 'bob', plan: 'free', createdAt: new Ts(NOW - D) });
    await S.useCredit(deps, 'alice', use(ID1));
    assert.equal(deps.db.data('invites', ID1).createdAt.toMillis(), NOW - 2 * D);
    await assert.rejects(S.useCredit(deps, 'alice', use(ID2)), (e) => e.reason === 'already-paid');
    await assert.rejects(S.useCredit(deps, 'alice', use(ID3)), (e) => e.reason === 'not-owner');
    assert.equal(credits(deps, 'alice').balance, 2);
  });

  test('başka kullanıcının bakiyesi kullanılamaz; oturumsuz / bozuk girdi ret', async () => {
    const { deps } = setup();
    await S.redeem(deps, 'alice', bundleIn());
    await assert.rejects(S.useCredit(deps, 'bob', use(ID1)), (e) => e.reason === 'no-credit');
    await assert.rejects(S.useCredit(deps, null, use(ID1)), (e) => e.code === 'unauthenticated');
    await assert.rejects(S.useCredit(deps, 'alice', { inviteId: 'kisa', data: dataJson() }), (e) => e.reason === 'bad-invite-id');
    await assert.rejects(S.useCredit(deps, 'alice', { inviteId: ID1 }), (e) => e.reason === 'bad-data');
    await assert.rejects(S.useCredit(deps, 'alice', { inviteId: ID1, data: 'x' }), (e) => e.reason === 'bad-data');
    assert.equal(credits(deps, 'alice').balance, 3);
  });
});

describe('paket iadesi (voidedPurchases)', () => {
  test('kalan haklar silinir, paketle yayınlanan davetiyeler 24 saatte kapanır, premium yeniden hesaplanır, idempotent', async () => {
    const { deps } = setup({ [BTOKEN]: purchased() }, [{ purchaseToken: BTOKEN, voidedTimeMillis: String(NOW), voidedSource: 0, voidedReason: 1 }]);
    await S.redeem(deps, 'alice', withInvite(ID1));
    await S.useCredit(deps, 'alice', use(ID2));
    const r = await S.processVoided(deps);
    assert.deepEqual(r, { seen: 1, applied: 1 });
    const c = credits(deps, 'alice');
    assert.equal(c.balance, 0);
    assert.equal(c.lots[0].voided, true);
    assert.equal(c.ledger.at(-1).t, 'void');
    assert.equal(c.ledger.at(-1).n, -1);
    for (const id of [ID1, ID2]) {
      assert.equal(deps.db.data('invites', id).expiresAt.toMillis(), NOW + D);
      assert.equal(deps.db.data('invites', id).plan, 'paid');
    }
    const rec = deps.db.data('purchases', L.sha256(BTOKEN));
    assert.equal(rec.voided, true);
    assert.equal(rec.creditsRemoved, 1);
    assert.equal(deps.db.data('users', 'alice').premium, false);
    await assert.rejects(S.useCredit(deps, 'alice', use(ID3)), (e) => e.reason === 'no-credit');
    await assert.rejects(S.redeem(deps, 'alice', bundleIn()), (e) => e.reason === 'voided');
    assert.deepEqual(await S.processVoided(deps), { seen: 1, applied: 0 });
  });

  test('bir paketin iadesi diğer paketin haklarına ve tekli alımla yayınlanan davetiyeye dokunmaz', async () => {
    const T2 = 'bundle-token-second-999';
    const TS = 'single-token-123456';
    const { deps } = setup({ [BTOKEN]: purchased(), [T2]: purchased(), [TS]: purchased() }, [{ purchaseToken: BTOKEN }]);
    await S.redeem(deps, 'alice', withInvite(ID1));
    await S.redeem(deps, 'alice', bundleIn({ purchaseToken: T2 }));
    await S.redeem(deps, 'alice', { inviteId: ID4, purchaseToken: TS, productId: 'zarfla_invite_1', data: dataJson() });
    assert.equal(credits(deps, 'alice').balance, 5);
    await S.processVoided(deps);
    assert.equal(credits(deps, 'alice').balance, 3);
    assert.equal(deps.db.data('invites', ID1).expiresAt.toMillis(), NOW + D);
    assert.equal(deps.db.data('invites', ID4).expiresAt.toMillis(), NOW + L.PAID_LIFE_MS);
    assert.equal(deps.db.data('users', 'alice').premium, true);
    // kalan haklar ikinci paketten kullanılmaya devam eder
    assert.equal((await S.useCredit(deps, 'alice', use(ID2))).credits, 2);
  });
});
