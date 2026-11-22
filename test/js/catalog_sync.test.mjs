// Katalog eşitliği: lib/data/catalog.dart (kLayouts/kOpenings) ile davetli sayfası (invite.html LAYOUTS/OPENINGS/OPEN_MS/openers)
// aynı kimlikleri içermeli. Ayrıca her düzen için render dalı, her açılış için şablon ve 4 dilde ARB etiketi bulunmalı.
// Çalıştırma: node --test test/js/catalog_sync.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const rd = (p) => readFileSync(new URL('../../' + p, import.meta.url), 'utf8');
const html = rd('assets/invite/invite.html');
const dart = rd('lib/data/catalog.dart');
const dartList = (name) => {
  const m = new RegExp(`const List<String> ${name} = \\[([^\\]]*)\\];`).exec(dart);
  assert.ok(m, name + ' bulunamadı');
  return [...m[1].matchAll(/'([a-z0-9]+)'/g)].map((x) => x[1]);
};
const jsList = (name) => {
  const m = new RegExp(`const ${name}=\\[([^\\]]*)\\];`).exec(html);
  assert.ok(m, name + ' bulunamadı');
  return JSON.parse('[' + m[1] + ']');
};
const kLayouts = dartList('kLayouts');
const kOpenings = dartList('kOpenings');
const LAYOUTS = jsList('LAYOUTS');
const OPENINGS = jsList('OPENINGS');
const WAVE3_LAYOUTS = ['galeri', 'mektup', 'davetkarti', 'minimal', 'gece', 'hikaye'];
const WAVE3_OPENINGS = ['zarfacil', 'muhurkir', 'kagitkatla', 'parilti', 'lale', 'fener', 'kapikemer', 'konfeti'];

test('düzenler: katalog ↔ invite.html aynı (sıra dahil)', () => {
  assert.deepEqual(kLayouts, LAYOUTS);
  assert.equal(new Set(kLayouts).size, kLayouts.length);
  for (const k of WAVE3_LAYOUTS) assert.ok(kLayouts.includes(k), k);
});

test('açılışlar: katalog ↔ invite.html aynı (sıra dahil)', () => {
  assert.deepEqual(kOpenings, OPENINGS);
  assert.equal(new Set(kOpenings).size, kOpenings.length);
  for (const k of WAVE3_OPENINGS) assert.ok(kOpenings.includes(k), k);
});

test('her açılışın süresi (OPEN_MS) ve şablonu (openers) var', () => {
  const ms = /const OPEN_MS=\{([^}]*)\};/.exec(html);
  assert.ok(ms);
  const msKeys = [...ms[1].matchAll(/([a-z0-9]+):(\d+)/g)].map((x) => x[1]);
  assert.deepEqual([...msKeys].sort(), [...kOpenings].sort());
  const a = html.indexOf('const openers={');
  assert.ok(a > 0, 'openers bulunamadı');
  const body = html.slice(a, html.indexOf('\n  };', a));
  for (const k of kOpenings) assert.match(body, new RegExp(`(^|[\\s,{])${k}:`), 'şablon yok: ' + k);
});

test('her yeni düzenin render dalı var (klasik varsayılana düşmez)', () => {
  for (const k of WAVE3_LAYOUTS) assert.ok(html.includes(`lay==="${k}"`), 'dal yok: ' + k);
  for (const k of WAVE3_LAYOUTS) assert.ok(html.includes(`.lay-${k}`), 'CSS yok: ' + k);
});

test('7 dilde lay_*/opn_* etiketleri', () => {
  for (const l of ['tr', 'en', 'de', 'ar', 'es', 'pt', 'id']) {
    const arb = JSON.parse(rd(`assets/l10n/app_${l}.arb`));
    for (const k of kLayouts) assert.ok(String(arb['lay_' + k] || '').trim(), `${l}: lay_${k}`);
    for (const k of kOpenings) assert.ok(String(arb['opn_' + k] || '').trim(), `${l}: opn_${k}`);
  }
});

test('davetli sayfası dış adres yüklemez (CSP: yalnız satır içi)', () => {
  const urls = [...html.matchAll(/url\(\s*["']?(https?:)?\/\//g)];
  assert.equal(urls.length, 0, 'CSS url() dış adres');
  assert.ok(!/<script[^>]+src=/.test(html), 'harici script');
  assert.ok(!/<link[^>]+stylesheet/.test(html), 'harici stil');
});
