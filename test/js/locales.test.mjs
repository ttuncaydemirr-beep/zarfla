// Yeni davetli sayfası dilleri (es / pt / id): sözlük tamlığı, yer tutucular, tarih biçimi, çıktıda eksik metin yok.
// Çalıştırma: node --test test/js/locales.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const rd = (p) => readFileSync(new URL('../../' + p, import.meta.url), 'utf8');
const html = rd('assets/invite/invite.html');
const s0 = html.lastIndexOf('<script>');
const s1 = html.indexOf('(function boot(){', s0);
assert.ok(s0 > 0 && s1 > s0, 'motor betiği bulunamadı');
const engine = html.slice(s0 + '<script>'.length, s1);
const STOP = new Error('captured');
const ctx = {
  Intl, URLSearchParams, URL, Math, Date, JSON, Object, Array, String, Number, encodeURIComponent,
  console, setTimeout, clearTimeout, setInterval, clearInterval,
  window: {}, location: { protocol: 'https:', search: '', hash: '', origin: 'https://zarfla-37da9.web.app' },
  navigator: { languages: ['tr'] }, matchMedia: () => ({ matches: true }),
  document: { documentElement: {}, title: '', hidden: false, addEventListener() {}, removeEventListener() {}, getElementById: () => ctx.__host },
};
ctx.__host = { set innerHTML(v) { ctx.__html = v; throw STOP; } };
vm.createContext(ctx);
vm.runInContext(engine + '\nthis.api={mountInvite,G,EYEBROW,LOCALE,PH,THEMES,LAYOUTS,fmtISO};', ctx);
const { G, EYEBROW, LOCALE, PH, THEMES, LAYOUTS, fmtISO } = ctx.api;
const NEW = ['es', 'pt', 'id'];
const ALL = ['tr', 'en', 'de', 'ar', ...NEW];
const ph = (v) => [...String(v).matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(',');

test('G sözlüğü: yeni dillerde en ile aynı anahtarlar (+rsvpJump/waHow), boş yok, yer tutucular aynı', () => {
  for (const l of NEW) {
    const base = new Set([...Object.keys(G.en), 'rsvpJump', 'waHow']);
    assert.deepEqual(new Set(Object.keys(G[l])), base, l);
    for (const [k, v] of Object.entries(G[l])) {
      if (k === 'units') { assert.equal(v.length, 4, l + ' units'); v.forEach((u) => assert.ok(u.trim())); continue; }
      assert.ok(String(v).trim(), `${l}.${k} boş`);
      if (k in G.en) assert.equal(ph(v), ph(G.en[k]), `${l}.${k} yer tutucusu`);
    }
    assert.notEqual(G[l].send, G.en.send, l + ' çevrilmemiş');
  }
});

test('EYEBROW, PH, LOCALE ve tasarım adları yedi dilde tam', () => {
  const types = Object.keys(EYEBROW.en);
  for (const l of ALL) {
    assert.deepEqual(Object.keys(EYEBROW[l]).sort(), [...types].sort(), 'EYEBROW ' + l);
    assert.ok(PH[l].ph1 && PH[l].ph2 && PH[l].phOne, 'PH ' + l);
    assert.ok(LOCALE[l], 'LOCALE ' + l);
    for (const th of Object.values(THEMES)) assert.ok(String(th.name[l] || '').trim(), `${th.name.en}/${l}`);
  }
});

test('EYEBROW metinleri uygulama ARB eyebrow_* ile aynı', () => {
  for (const l of NEW) {
    const arb = JSON.parse(rd(`assets/l10n/app_${l}.arb`));
    for (const [ty, v] of Object.entries(EYEBROW[l])) assert.equal(v, arb['eyebrow_' + ty], `${l}.${ty}`);
  }
});

test('tarih biçimi yerel ay adlarıyla', () => {
  assert.match(fmtISO('2027-06-12', 'es'), /jun/i);
  assert.match(fmtISO('2027-06-12', 'pt'), /jun/i);
  assert.match(fmtISO('2027-03-12', 'id'), /mar/i);
  const long = (l) => new Intl.DateTimeFormat(LOCALE[l], { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(Date.UTC(2027, 7, 14, 12)));
  assert.match(long('es'), /sábado/i); assert.match(long('es'), /agosto/i);
  assert.match(long('pt'), /sábado/i); assert.match(long('pt'), /agosto/i);
  assert.match(long('id'), /sabtu/i); assert.match(long('id'), /agustus/i);
});

function render(over) {
  const inv = {
    id: 'AbCdEf123456', type: 'dugun', theme: 'papatya', lang: 'es', layout: 'klasik', opening: 'door',
    n1: 'Ana', n2: 'Luis', host: '', msg: 'Hola', date: '2027-06-12', time: '19:00', end: '',
    venue: 'Salón', address: 'Calle 1', wa: '5215512345678', program: [{ t: '19:00', x: 'Bienvenida' }], notes: ['Nota'],
    cover: '', photos: [], status: 'live', plan: 'free', ...over,
  };
  ctx.__html = null;
  try { ctx.api.mountInvite(ctx.__host, inv, true); } catch (e) { if (e !== STOP) throw e; }
  assert.ok(ctx.__html, 'çıktı yok');
  return ctx.__html;
}

test('her yeni dilde her düzen: çıktı o dilin metnini içerir, "undefined" ve Türkçe sızıntı yok, yön ltr', () => {
  for (const l of NEW) {
    for (const lay of LAYOUTS) {
      const out = render({ lang: l, layout: lay });
      assert.ok(!out.includes('undefined'), `${l}/${lay} undefined`);
      assert.ok(out.includes(`lang="${l}"`) && out.includes('dir="ltr"'), `${l}/${lay} lang/dir`);
      assert.ok(out.includes(G[l].rsvpT), `${l}/${lay} rsvpT`);
      assert.ok(out.includes(EYEBROW[l].dugun), `${l}/${lay} eyebrow`);
      assert.ok(out.includes(G[l].made.replace(/&/g, '&amp;')), `${l}/${lay} made`);
      assert.ok(!out.includes(G.tr.rsvpT), `${l}/${lay} Türkçe sızıntı`);
    }
  }
});

test('ücretli davetiye: IBAN uyarısı ve yeni dilde müzik künyesi', () => {
  for (const l of NEW) {
    const out = render({ lang: l, plan: 'premium', gift: { n: 'Ana Diaz', i: 'ES9121000418450200051332', b: '' }, live: { u: 'https://youtu.be/x', n: '' }, theme: 'gul' });
    assert.ok(!out.includes('undefined'), l);
    assert.ok(out.includes(G[l].giftDisc.slice(0, 20)) || !out.includes('gift-card'), l + ' giftDisc');
  }
});

test('bilinmeyen dil Türkçeye düşer (beyaz liste)', () => {
  const out = render({ lang: 'xx' });
  assert.ok(out.includes('lang="tr"'));
});

test('hosting loader.js: es/pt/id durum metinleri tam', () => {
  const src = rd('hosting-src/loader.js');
  const t = src.slice(src.indexOf('const T={'), src.indexOf('function pickLang'));
  for (const l of ALL) {
    const m = new RegExp(`\\b${l}:\\{([^}]*)\\}`).exec(t);
    assert.ok(m, 'T.' + l);
    for (const k of ['title', 'loading', 'gone', 'err', 'retry', 'make']) assert.match(m[1], new RegExp(`${k}:"[^"]+"`), `${l}.${k}`);
  }
});
