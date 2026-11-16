// Davetli sayfasındaki (assets/invite/invite.html) müzik yardımcılarının Node birim testi.
// Oynatıcının tarayıcıdaki davranışı (dokununca başlama, kısık açılış, duraklatma, sekme gizlenince durma)
// başsız Chrome ile ayrıca sınanır. Çalıştırma: node --test test/js/music.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../../assets/invite/invite.html', import.meta.url), 'utf8');
const a = html.indexOf('/*MUSIC-BEGIN*/');
const b = html.indexOf('/*MUSIC-END*/');
assert.ok(a > 0 && b > a, 'MUSIC bloğu bulunamadı');
const ctx = {};
vm.createContext(ctx);
vm.runInContext(html.slice(a, b) + '\nthis.api={MUSIC,MUSIC_BASE,musicId,musicUrl,musicCreditHtml};', ctx);
const { MUSIC, MUSIC_BASE, musicId, musicUrl, musicCreditHtml } = ctx.api;
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const L = { musicL: 'Müzik', musicCut: 'kısaltıldı' };

test('yalnız ücretli plan ve seçkideki kimlik', () => {
  assert.equal(musicId({ plan: 'premium', music: 'dugun-wagner' }), 'dugun-wagner');
  assert.equal(musicId({ plan: 'free', music: 'dugun-wagner' }), '');
  assert.equal(musicId({ plan: 'paid', music: 'dugun-wagner' }), ''); // davetli sayfasında yerel ad "premium"
  for (const m of ['', 'yok', '../x', 'toString', '__proto__', 'constructor', 5, null, undefined]) {
    assert.equal(musicId({ plan: 'premium', music: m }), '', String(m));
  }
  assert.equal(musicId(null), '');
});

test('adres: kendi barındırmamız (Firebase Hosting) + <id>.mp3', () => {
  assert.equal(MUSIC_BASE, 'https://zarfla-37da9.web.app/music/');
  assert.equal(musicUrl('klasik-grieg'), MUSIC_BASE + 'klasik-grieg.mp3');
});

test('künye: CC BY parçada lisans bağlantısıyla, kamu malında yok', () => {
  const h = musicCreditHtml('dugun-wagner', L, esc);
  assert.match(h, /Müzik: “Wagner Bridal Chorus” – Kevin MacLeod \(incompetech\.com\)/);
  assert.match(h, /href="https:\/\/creativecommons\.org\/licenses\/by\/4\.0\/"[^>]*>CC BY 4\.0<\/a> · kısaltıldı/);
  assert.equal(musicCreditHtml('klasik-grieg', L, esc), '');
  assert.equal(musicCreditHtml('yok', L, esc), '');
  for (const [id, m] of Object.entries(MUSIC)) {
    assert.match(id, /^[a-z0-9-]{1,40}$/);
    assert.ok(m.by === 0 || m.by === 1, id);
    assert.ok(m.t && !/[<>"]/.test(m.t), id);
  }
  assert.ok(Object.keys(MUSIC).length >= 15 && Object.keys(MUSIC).length <= 20);
});
