'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const ST = require('../src/stats');
const { Ts, makeDeps } = require('./fakes');

const H = 3600 * 1000;
const D = 24 * H;
// 2026-11-15 12:00 UTC = İstanbul 15:00 (15 Kasım)
const NOW = Date.UTC(2026, 10, 15, 12, 0, 0);
// İstanbul'un 14 Kasım günü: 13 Kasım 21:00Z ... 14 Kasım 21:00Z
const DAY_START = Date.UTC(2026, 10, 13, 21, 0, 0);

/** stats testleri için en küçük sahte Firestore: tek alanlı aralık sorgusu + sıralama + select + limit + startAfter. */
class QDb {
  constructor() {
    this.cols = { invites: [], purchases: [] };
    this.written = new Map();
    this.queries = [];
  }
  collection(name) {
    const db = this;
    if (name === 'stats') {
      return {
        doc: (a) => ({
          collection: (b) => ({
            doc: (c) => ({
              set: async (data) => {
                db.written.set(`stats/${a}/${b}/${c}`, JSON.parse(JSON.stringify(data)));
              },
            }),
          }),
        }),
      };
    }
    const q = { name, where: [], order: null, sel: null, lim: Infinity, after: null };
    const api = {
      where(f, op, v) {
        q.where.push([f, op, v]);
        return api;
      },
      orderBy(f) {
        q.order = f;
        return api;
      },
      select(...f) {
        q.sel = f;
        return api;
      },
      limit(n) {
        q.lim = n;
        return api;
      },
      startAfter(doc) {
        q.after = doc;
        return api;
      },
      async get() {
        db.queries.push({ name, fields: q.sel, where: q.where.map((w) => `${w[0]} ${w[1]}`) });
        let rows = db.cols[name].filter((r) =>
          q.where.every(([f, op, v]) => {
            const x = r[f] && r[f].toMillis ? r[f].toMillis() : null;
            if (x == null) return false;
            return op === '>=' ? x >= v.toMillis() : op === '<' ? x < v.toMillis() : false;
          }),
        );
        rows = rows.sort((a, b) => a[q.order].toMillis() - b[q.order].toMillis());
        if (q.after) rows = rows.slice(rows.indexOf(q.after._row) + 1);
        rows = rows.slice(0, q.lim);
        const docs = rows.map((r) => ({
          _row: r,
          data: () => (q.sel ? Object.fromEntries(q.sel.filter((k) => k in r).map((k) => [k, r[k]])) : { ...r }),
        }));
        return { docs };
      },
    };
    return api;
  }
}

const dataJson = (o = {}) =>
  JSON.stringify({ id: 'AbCdEf123456', type: 'dugun', theme: 'altin', lang: o.lang ?? 'tr', layout: o.layout ?? 'klasik', opening: o.opening ?? 'door', n1: 'Ayşe Yılmaz', n2: 'Mehmet', wa: '905321234567', status: 'live' });

const invite = (o = {}) => ({
  ownerUid: 'uid-alice-secret',
  plan: o.plan ?? 'free',
  status: 'live',
  type: o.type ?? 'dugun',
  theme: o.theme ?? 'papatya',
  n1: 'Ayşe Yılmaz',
  n2: 'Mehmet',
  data: o.data ?? dataJson(o),
  createdAt: new Ts(o.at ?? DAY_START + 3 * H),
});

const purchase = (o = {}) => ({
  uid: 'uid-alice-secret',
  inviteId: 'AbCdEf123456',
  productId: o.productId ?? 'zarfla_invite_1',
  orderId: 'GPA.3333-1111',
  upgrade: o.upgrade ?? false,
  voided: o.voided ?? false,
  grantedAt: new Ts(o.at ?? DAY_START + 5 * H),
});

describe('stats · gün hesapları', () => {
  test('istanbulDay ve dayRange (UTC+3 sabit)', () => {
    assert.equal(ST.istanbulDay(Date.UTC(2026, 10, 14, 20, 59, 59)), '2026-11-14');
    assert.equal(ST.istanbulDay(Date.UTC(2026, 10, 14, 21, 0, 0)), '2026-11-15');
    const r = ST.dayRange('2026-11-14');
    assert.equal(r.startMs, DAY_START);
    assert.equal(r.endMs, DAY_START + D);
  });

  test('dayRange geçersiz günleri reddeder', () => {
    for (const bad of ['2026-02-31', '2026-13-01', 'dün', '', null, undefined, '2026-1-1']) {
      assert.throws(() => ST.dayRange(bad), /bad-day/, String(bad));
    }
  });

  test('previousDay: İstanbul takvimine göre dün (UTC gece yarısı değil)', () => {
    assert.equal(ST.previousDay(NOW), '2026-11-14');
    assert.equal(ST.previousDay(Date.UTC(2026, 10, 15, 22, 0, 0)), '2026-11-15'); // İstanbul'da 16 Kasım 01:00
    assert.equal(ST.previousDay(Date.UTC(2026, 10, 15, 20, 59, 0)), '2026-11-14');
  });
});

describe('stats · toplama', () => {
  test('inviteTraits: yalnız lang/layout/opening; bozuk ve kötü niyetli değerler "other"', () => {
    assert.deepEqual(ST.inviteTraits(dataJson({ lang: 'de', layout: 'modern', opening: 'envelope' })), { lang: 'de', layout: 'modern', opening: 'envelope' });
    for (const lang of ['tr', 'en', 'ar', 'es', 'pt', 'id']) {
      assert.equal(ST.inviteTraits(dataJson({ lang, layout: 'modern', opening: 'envelope' })).lang, lang, lang);
    }
    assert.deepEqual(ST.inviteTraits('{bozuk'), { lang: 'other', layout: 'other', opening: 'other' });
    assert.deepEqual(ST.inviteTraits(undefined), { lang: 'other', layout: 'other', opening: 'other' });
    assert.deepEqual(ST.inviteTraits('[1]'), { lang: 'other', layout: 'other', opening: 'other' });
    const evil = ST.inviteTraits(JSON.stringify({ lang: 'xx', layout: 'a b', opening: 'x'.repeat(100) }));
    assert.deepEqual(evil, { lang: 'other', layout: 'other', opening: 'other' });
  });

  test('aggregateInvites: tür/tasarım/açılış/düzen/dil/plan sayımları', () => {
    const r = ST.aggregateInvites([
      invite({ type: 'dugun', theme: 'papatya', plan: 'free', lang: 'tr' }),
      invite({ type: 'dugun', theme: 'altin', plan: 'paid', lang: 'tr', opening: 'envelope', layout: 'modern' }),
      invite({ type: 'dogum', theme: 'altin', plan: 'paid', lang: 'ar' }),
      invite({ type: 'dogum', theme: 'papatya', plan: 'weird', lang: 'de' }),
    ]);
    assert.equal(r.created, 4);
    assert.equal(r.published, 4);
    assert.deepEqual(r.byType, { dugun: 2, dogum: 2 });
    assert.deepEqual(r.byTheme, { papatya: 2, altin: 2 });
    assert.deepEqual(r.byPlan, { free: 1, paid: 2, other: 1 });
    assert.deepEqual(r.byLanguage, { tr: 2, ar: 1, de: 1 });
    assert.deepEqual(r.byOpening, { door: 3, envelope: 1 });
    assert.deepEqual(r.byLayout, { klasik: 3, modern: 1 });
  });

  test('aggregateInvites: farklı anahtar sayısı sınırlı (kalanı "other")', () => {
    const docs = [];
    for (let i = 0; i < 60; i++) docs.push(invite({ theme: `t${i}` }));
    const r = ST.aggregateInvites(docs);
    assert.ok(Object.keys(r.byTheme).length <= ST.MAX_KEYS + 1);
    assert.equal(Object.values(r.byTheme).reduce((a, b) => a + b, 0), 60);
    assert.ok(r.byTheme.other >= 60 - ST.MAX_KEYS);
  });

  test('aggregatePurchases: ürün, yükseltme, iade', () => {
    const r = ST.aggregatePurchases([purchase(), purchase({ upgrade: true }), purchase({ voided: true }), purchase({ productId: 'Kötü Ürün!' })]);
    assert.deepEqual(r, { granted: 4, byProduct: { zarfla_invite_1: 3, other: 1 }, upgrades: 1, voided: 1 });
  });
});

describe('stats · dailyStats', () => {
  function rig() {
    const db = new QDb();
    // 14 Kasım (İstanbul) içinde
    db.cols.invites.push(invite({ at: DAY_START }), invite({ at: DAY_START + D - 1, plan: 'paid', theme: 'altin' }));
    // gün dışında: bir ms önce, tam gün sonu (dışlayıcı)
    db.cols.invites.push(invite({ at: DAY_START - 1 }), invite({ at: DAY_START + D }));
    db.cols.purchases.push(purchase({ at: DAY_START + H }), purchase({ at: DAY_START + D + 1 }));
    return { db, deps: makeDeps({ db, now: () => NOW }) };
  }

  test('dünün sayımları stats/daily/days/{gün} belgesine yazılır; sınırlar doğru', async () => {
    const { db, deps } = rig();
    const doc = await ST.dailyStats(deps);
    const w = db.written.get('stats/daily/days/2026-11-14');
    assert.ok(w, 'belge yazıldı');
    assert.equal(w.day, '2026-11-14');
    assert.equal(w.schema, 1);
    assert.equal(w.invitations.created, 2);
    assert.deepEqual(w.invitations.byPlan, { free: 1, paid: 1 });
    assert.equal(w.purchases.granted, 1);
    assert.equal(doc.invitations.created, 2);
  });

  test('çıktıda kişisel veri yok: uid, isim, telefon, sipariş, davetiye kimliği, jeton', async () => {
    const { db, deps } = rig();
    await ST.dailyStats(deps);
    const text = JSON.stringify([...db.written.values()]);
    for (const secret of ['uid-alice-secret', 'Ayşe', 'Mehmet', '905321234567', 'GPA.3333', 'AbCdEf123456']) {
      assert.equal(text.includes(secret), false, `sızdı: ${secret}`);
    }
  });

  test('yalnız gerekli alanlar sorgulanır (ownerUid, isimler, telefon okunmaz) ve tek alanlı aralık kullanılır', async () => {
    const { db, deps } = rig();
    await ST.dailyStats(deps);
    for (const q of db.queries) {
      for (const banned of ['ownerUid', 'uid', 'n1', 'n2', 'wa', 'orderId', 'inviteId']) {
        assert.equal(q.fields.includes(banned), false, `${q.name}: ${banned} seçildi`);
      }
      assert.deepEqual(q.where.map((x) => x.split(' ')[0]).filter((v, i, a) => a.indexOf(v) === i).length, 1, 'tek alan → bileşik indeks gerekmez');
    }
    const names = db.queries.map((q) => q.name);
    assert.ok(names.includes('invites') && names.includes('purchases'));
  });

  test('belirli gün verilebilir; yeniden çalıştırmak aynı sayıları yazar (idempotent)', async () => {
    const { db, deps } = rig();
    await ST.dailyStats(deps, { day: '2026-11-14' });
    const a = { ...db.written.get('stats/daily/days/2026-11-14') };
    await ST.dailyStats(deps, { day: '2026-11-14' });
    const b = db.written.get('stats/daily/days/2026-11-14');
    delete a.generatedAt;
    const bb = { ...b };
    delete bb.generatedAt;
    assert.deepEqual(bb, a);
    assert.equal(db.written.size, 1);
    await assert.rejects(() => ST.dailyStats(deps, { day: '2026-02-31' }), /bad-day/);
  });

  test('sayfalama: PAGE_SIZE\'tan fazla belge eksiksiz sayılır', async () => {
    const db = new QDb();
    const n = ST.PAGE_SIZE * 2 + 50;
    for (let i = 0; i < n; i++) db.cols.invites.push(invite({ at: DAY_START + i + 1 }));
    const doc = await ST.dailyStats(makeDeps({ db, now: () => NOW }));
    assert.equal(doc.invitations.created, n);
    assert.equal(db.queries.filter((q) => q.name === 'invites').length, 3);
  });

  test('boş gün: sıfır sayımlı belge yazılır', async () => {
    const db = new QDb();
    const doc = await ST.dailyStats(makeDeps({ db, now: () => NOW }));
    assert.equal(doc.invitations.created, 0);
    assert.deepEqual(doc.invitations.byType, {});
    assert.equal(doc.purchases.granted, 0);
    assert.ok(db.written.has('stats/daily/days/2026-11-14'));
  });
});
