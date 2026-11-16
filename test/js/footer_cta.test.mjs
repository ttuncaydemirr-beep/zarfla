// Davetli sayfası alt yazısı ("Zarfla ile hazırlandı · Sen de 2 dakikada hazırla") — yalnız ücretsiz davetiyede, Play bağlantısı.
// Çalıştırma: node --test test/js/footer_cta.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../../assets/invite/invite.html', import.meta.url), 'utf8');
const a = html.indexOf('const PLAY_URL=');
const b = html.indexOf('/*MUSIC-BEGIN*/');
assert.ok(a > 0 && b > a, 'alt yazı bloğu bulunamadı');
const L = { made: 'Zarfla ile hazırlandı', madeCta: 'Sen de 2 dakikada hazırla' };
const load = (win) => {
  const ctx = { window: win };
  vm.createContext(ctx);
  vm.runInContext(html.slice(a, b) + '\nthis.api={playUrl,madeByHtml};', ctx);
  return ctx.api;
};
const PLAY = 'https://play.google.com/store/apps/details?id=com.demirgamesstudio.zarfla';

test('Play bağlantısı: kurulum yönlendiricisi tema ile', () => {
  const { playUrl } = load({});
  assert.equal(playUrl('papatya'), PLAY + '&referrer=utm_source%3Dguest_footer%26utm_campaign%3Dpapatya');
  assert.equal(playUrl('expired'), PLAY + '&referrer=utm_source%3Dguest_footer%26utm_campaign%3Dexpired');
  assert.equal(playUrl(''), PLAY + '&referrer=utm_source%3Dguest_footer%26utm_campaign%3Dnone');
  assert.equal(playUrl(undefined), PLAY + '&referrer=utm_source%3Dguest_footer%26utm_campaign%3Dnone');
  // tema kimliği dışındaki karakterler atılır (bağlantı/HTML kırılamaz)
  assert.equal(playUrl('"><x&y=1'), PLAY + '&referrer=utm_source%3Dguest_footer%26utm_campaign%3Dxy1');
});

test('davetli sayfasında küçük bağlantı, yeni sekmede', () => {
  const { madeByHtml } = load({});
  const h = madeByHtml({ theme: 'gul' }, L);
  assert.match(h, /^<a class="madeby" href="https:\/\/play\.google\.com\/[^"]+utm_campaign%3Dgul" target="_blank" rel="noopener">/);
  assert.match(h, /Zarfla ile hazırlandı.*Sen de 2 dakikada hazırla/);
});

test('uygulama içi önizlemede (ZarflaApp) aynı metin, bağlantısız', () => {
  const { madeByHtml } = load({ ZarflaApp: { postMessage() {} } });
  const h = madeByHtml({ theme: 'gul' }, L);
  assert.match(h, /^<div class="madeby">/);
  assert.ok(!h.includes('href='));
});

test('ücretli davetiyede alt yazı çağrılmaz; dört dilde CTA metni var', () => {
  assert.ok(html.includes('${showMade?madeByHtml(inv,L):""}'));
  assert.ok(html.includes('const showMade=inv.plan!=="premium";'));
  for (const s of ['"madeCta":"Sen de 2 dakikada hazırla"', '"madeCta":"Make yours in 2 minutes"',
    '"madeCta":"Erstelle deine in 2 Minuten"', '"madeCta":"حضّر دعوتك في دقيقتين"']) {
    assert.ok(html.includes(s), s);
  }
});
