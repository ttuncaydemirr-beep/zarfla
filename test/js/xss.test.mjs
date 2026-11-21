// Davetli sayfası XSS regresyon testi (güvenlik denetimi H-1).
// Davetiye verisi güvenilmezdir: herkes anonim hesapla Firestore'a belge yazabilir. Bu test motoru (invite.html)
// Node vm içinde çalıştırır, kötü niyetli verilerle mountInvite'ın ürettiği HTML'i yakalar ve zararsız olduğunu doğrular.
// Çalıştırma: node --test test/js/xss.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../../assets/invite/invite.html', import.meta.url), 'utf8');
const s0 = html.lastIndexOf('<script>');
const s1 = html.indexOf('(function boot(){', s0);
assert.ok(s0 > 0 && s1 > s0, 'motor betiği bulunamadı');
const engine = html.slice(s0 + '<script>'.length, s1);

const STOP = new Error('captured');
function load() {
  const ctx = {
    Intl, URLSearchParams, URL, Math, Date, JSON, Object, Array, String, Number, encodeURIComponent,
    console, setTimeout, clearTimeout, setInterval, clearInterval,
    window: {}, location: { protocol: 'https:', search: '', hash: '', origin: 'https://zarfla-37da9.web.app' },
    navigator: { languages: ['tr'] }, matchMedia: () => ({ matches: true }),
    document: {
      documentElement: {}, title: '', hidden: false, addEventListener() {}, removeEventListener() {},
      getElementById: () => ctx.__host,
    },
  };
  ctx.__host = {
    set innerHTML(v) { ctx.__html = v; throw STOP; },
  };
  vm.createContext(ctx);
  vm.runInContext(engine + '\nthis.api={mountInvite,normInv,safeImg,esc,attr};', ctx);
  return ctx;
}
const ctx = load();
const { normInv, safeImg } = ctx.api;

const LAYOUTS = ['klasik', 'kemer', 'monogram', 'editoryal', 'kartpostal', 'zamancizelgesi', 'bilet',
  'galeri', 'mektup', 'davetkarti', 'minimal', 'gece', 'hikaye'];
const GOOD = 'https://firebasestorage.googleapis.com/v0/b/zarfla-37da9.firebasestorage.app/o/invites%2FAbCdEf123456%2Fcover.jpg?alt=media&token=0b1c2d3e-aaaa-bbbb-cccc-1234567890ab';
const GOOD_G = 'https://firebasestorage.googleapis.com/v0/b/zarfla-37da9.firebasestorage.app/o/invites%2FAbCdEf123456%2Fg1.webp?alt=media&token=0b1c2d3e-aaaa-bbbb-cccc-1234567890ab';
const DATA = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2w==';

const BREAKOUT = 'x" onerror="alert(1)';
const PAYLOADS = [
  BREAKOUT,
  '"><script>alert(1)</script>',
  "x' onerror='alert(1)",
  'javascript:alert(1)',
  ' JaVaScRiPt:alert(1)',
  'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
  'data:image/svg+xml;base64,PHN2ZyBvbmxvYWQ9YWxlcnQoMSk+',
  'https://evil.example/x.png',
  'https://firebasestorage.googleapis.com/v0/b/evil-bucket/o/invites%2FAbCdEf123456%2Fcover.jpg?alt=media',
  `${GOOD}" onerror="alert(1)`,
  `${GOOD}&x=" onload="alert(1)`,
];

function render(over) {
  const inv = {
    id: 'AbCdEf123456', type: 'dugun', theme: 'papatya', lang: 'tr', layout: 'klasik', opening: 'door',
    n1: 'Ayşe', n2: 'Can', host: '', msg: 'Merhaba', date: '2027-06-12', time: '19:00', end: '',
    venue: 'Salon', address: 'İstanbul', wa: '905551112233', program: [{ t: '19:00', x: 'Karşılama' }], notes: ['Not'],
    cover: '', photos: [], status: 'live', plan: 'premium', ...over,
  };
  ctx.__html = null;
  try {
    ctx.api.mountInvite(ctx.__host, inv, true);
  } catch (e) {
    if (e !== STOP) throw e;
  }
  assert.ok(typeof ctx.__html === 'string', 'HTML yakalanamadı');
  return ctx.__html;
}

// Üretilen HTML'de veri kaynaklı tehlikeli bir şey olmamalı. (Motorun kendi işaretlemesinde on*= ya da <script> yok.)
function assertClean(h, label) {
  assert.ok(!/<script/i.test(h), `${label}: <script> sızdı`);
  // Etiketlerin içinde (tırnaklı değerler çıkarıldıktan sonra) on*= özniteliği olmamalı. Kaçışlı metin (&lt;img …) etiket değildir.
  for (const m of h.matchAll(/<[a-zA-Z][^>]*>/g)) {
    const bare = m[0].replace(/"[^"]*"|'[^']*'/g, '""');
    assert.ok(!/\son[a-z]+\s*=/i.test(bare), `${label}: olay işleyici özniteliği sızdı: ${m[0].slice(0, 120)}`);
  }
  assert.ok(!/javascript:/i.test(h), `${label}: javascript: sızdı`);
  assert.ok(!/data:text|svg\+xml/i.test(h), `${label}: tehlikeli data: URL sızdı`);
  assert.ok(!/evil/i.test(h), `${label}: yabancı alan adı sızdı`);
  // Her src="…" değeri ya boş ya da izinli bir görsel adresi (HTML çözülmüş hâliyle).
  for (const m of h.matchAll(/\ssrc="([^"]*)"/g)) {
    const v = m[1].replace(/&amp;/g, '&');
    assert.ok(safeImg(v) === v && v !== '', `${label}: izinsiz src ${m[1].slice(0, 80)}`);
  }
}

test('safeImg: yalnız Zarfla Storage kovası ve base64 data:image (svg yok)', () => {
  assert.equal(safeImg(GOOD), GOOD);
  assert.equal(safeImg(GOOD_G), GOOD_G);
  assert.equal(safeImg(GOOD.replace(/&token=.*/, '')), GOOD.replace(/&token=.*/, ''));
  assert.equal(safeImg(DATA), DATA);
  for (const p of PAYLOADS) assert.equal(safeImg(p), '', p);
  assert.equal(safeImg(null), '');
  assert.equal(safeImg({ toString: () => GOOD }), '');
  assert.equal(safeImg(GOOD.replace('cover', 'g7')), '');
  assert.equal(safeImg(GOOD.replace('.jpg', '.svg')), '');
  assert.equal(safeImg(GOOD.replace('.jpg', '.html')), '');
});

test('normInv: kimlikler beyaz listede, prototip anahtarları reddedilir', () => {
  const i = normInv({
    id: '"><img src=x onerror=alert(1)>', theme: '__proto__', lang: 'constructor', type: 'toString',
    layout: 'x"><script>', opening: 'hasOwnProperty', date: '2027-01-01"><b>', time: '19:00<script>', end: 'x',
    wa: '90<b>555', cover: BREAKOUT, photos: [BREAKOUT, GOOD_G, 'javascript:alert(1)', 5, null], program: [null, 'x', { t: 1, x: '<b>' }],
  });
  assert.equal(i.id, 'zarfla');
  assert.equal(i.theme, 'papatya');
  assert.equal(i.lang, 'tr');
  assert.equal(i.type, 'diger');
  assert.equal(i.layout, 'klasik');
  assert.equal(i.opening, 'door');
  assert.equal(i.date, '');
  assert.equal(i.time, '');
  assert.equal(i.end, '');
  assert.equal(i.wa, '90555');
  assert.equal(i.cover, '');
  assert.deepEqual([...i.photos], [GOOD_G]);
  assert.equal(i.program.length, 1);
});

test('kapak/galeri saldırı yükleri her düzende etkisiz', () => {
  for (const layout of LAYOUTS) {
    for (const p of PAYLOADS) {
      const h = render({ layout, cover: p, photos: [p, p] });
      assertClean(h, `${layout} / ${p.slice(0, 30)}`);
    }
  }
});

test('meşru kapak ve galeri adresleri korunur (öznitelikte & kaçışlı)', () => {
  for (const layout of LAYOUTS) {
    const h = render({ layout, cover: GOOD, photos: [GOOD_G] });
    assertClean(h, layout);
    assert.ok(h.includes(GOOD.replace(/&/g, '&amp;')) || layout === 'galeri', `${layout}: kapak kayboldu`);
  }
  const g = render({ layout: 'galeri', cover: '', photos: [GOOD_G] });
  assert.ok(g.includes(GOOD_G.replace(/&/g, '&amp;')));
  const d = render({ cover: DATA, photos: [DATA] });
  assert.ok(d.includes(`src="${DATA}"`));
});

test('metin alanları kaçışlı: isimler, mesaj, notlar, program, mekân, adres, canlı yayın, IBAN, ?g=', () => {
  const X = '"><script>alert(1)</script><img src=x onerror=alert(1)>';
  for (const layout of LAYOUTS) {
    for (const opening of ['door', 'zarfacil', 'muhurkir', 'muhur']) {
      const h = render({
        layout, opening, n1: X, n2: X, host: X, msg: X, venue: X, address: X, notes: [X], program: [{ t: X, x: X }],
        live: { url: 'https://youtube.com/live/abc" onmouseover="alert(1)', note: X },
        gift: { holder: X, iban: 'TR33 0006 1005 1978 6457 8413 26', bank: X },
        guest: X, music: 'dugun-wagner"><script>',
      });
      assertClean(h, `${layout}/${opening}`);
      assert.ok(h.includes('&lt;script&gt;'), 'metin kaçışlı basılmalı');
    }
  }
});

test('canlı yayın: javascript: ve tırnak kırma kabul edilmez', () => {
  for (const url of ['javascript:alert(1)', 'https://a.b/"onclick="x', 'http://a.b/x', 'data:text/html,x']) {
    const h = render({ live: { url, note: '' } });
    assertClean(h, url);
    assert.ok(!h.includes('data-live'), `canlı yayın kartı çıkmamalı: ${url}`);
  }
});

test('id ile seçici/öznitelik kırma yok', () => {
  const h = render({ id: 'a" onfocus="alert(1)' });
  assertClean(h, 'id');
  assert.ok(h.includes('id="rnzarfla"'));
});
