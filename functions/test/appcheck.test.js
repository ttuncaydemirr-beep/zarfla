'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const AC = require('../src/appcheck');

const mkLog = () => {
  const calls = [];
  return { calls, info: (...a) => calls.push(a) };
};

describe('appcheck', () => {
  test('izleme kipi: enforceAppCheck alanı eklenmez, taban seçenekler korunur', () => {
    const o = AC.callOptions(false, { timeoutSeconds: 60 });
    assert.deepEqual(o, { timeoutSeconds: 60 });
    assert.equal('enforceAppCheck' in o, false);
  });

  test('zorlama kipi: enforceAppCheck true eklenir, taban nesne değişmez', () => {
    const base = { timeoutSeconds: 30 };
    assert.deepEqual(AC.callOptions(true, base), { timeoutSeconds: 30, enforceAppCheck: true });
    assert.deepEqual(base, { timeoutSeconds: 30 });
  });

  test('monitorAppCheck: jetonlu istek verified=true, jetonsuz false; yalnız fn+bool günlüğe (PII yok)', () => {
    const log = mkLog();
    assert.equal(AC.monitorAppCheck({ app: { appId: '1:2:android:3' }, auth: { uid: 'u1' }, rawRequest: { ip: '1.2.3.4' } }, 'useCredit', log), true);
    assert.equal(AC.monitorAppCheck({ auth: { uid: 'u1' } }, 'useCredit', log), false);
    assert.deepEqual(log.calls, [
      ['appcheck', { fn: 'useCredit', verified: true }],
      ['appcheck', { fn: 'useCredit', verified: false }],
    ]);
  });

  test('monitorAppCheck asla atmaz (günlükçü bozuk / istek boş)', () => {
    assert.equal(AC.monitorAppCheck(undefined, 'x', { info() { throw new Error('boom'); } }), false);
    assert.equal(AC.monitorAppCheck({ app: {} }, 'x', { info() { throw new Error('boom'); } }), true);
  });

  test('index.js: ENFORCE_APP_CHECK varsayılan false ve iki işlev de seçenekleri callOptions ile alıyor', () => {
    const src = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
    assert.match(src, /const ENFORCE_APP_CHECK = false;/);
    assert.match(src, /exports\.redeemPurchase = onCall\(AC\.callOptions\(ENFORCE_APP_CHECK,/);
    assert.match(src, /exports\.useCredit = onCall\(AC\.callOptions\(ENFORCE_APP_CHECK,/);
    assert.match(src, /monitorAppCheck\(req, 'redeemPurchase', logger\)/);
    assert.match(src, /monitorAppCheck\(req, 'useCredit', logger\)/);
  });
});
