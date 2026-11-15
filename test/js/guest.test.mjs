// Kişiye özel bağlantı (?g=Ad) temizleyicisinin Node birim testi.
// Çalıştırma: node --test test/js/guest.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../../assets/invite/invite.html', import.meta.url), 'utf8');
const a = html.indexOf('/*GUEST-BEGIN*/');
const b = html.indexOf('/*GUEST-END*/');
assert.ok(a > 0 && b > a, 'GUEST bloğu bulunamadı');
const ctx = { URLSearchParams };
vm.createContext(ctx);
vm.runInContext(html.slice(a, b) + '\nthis.api={cleanGuest,guestFromUrl,guestHiHtml,GUEST_MAX};', ctx);
const { cleanGuest, guestFromUrl, guestHiHtml, GUEST_MAX } = ctx.api;
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

test('temizleme: kırpma, boşluk, kontrol/yön karakterleri, uzunluk', () => {
  assert.equal(cleanGuest('  Ayşe   Teyze \n'), 'Ayşe Teyze');
  assert.equal(cleanGuest('A\u0000B‮C​D'), 'A B C D');
  assert.equal(cleanGuest(null), '');
  assert.equal(cleanGuest(42), '');
  assert.equal(cleanGuest('a'.repeat(90)).length, GUEST_MAX);
  assert.equal(Array.from(cleanGuest('😀'.repeat(70))).length, GUEST_MAX);
});

test('URL okuma: ?g= ve #g=, URL kodlu', () => {
  assert.equal(guestFromUrl('?id=AbCdEf123456&g=Ay%C5%9Fe%20%26%20Can', ''), 'Ayşe & Can');
  assert.equal(guestFromUrl('?id=x', '#g=Leyla'), 'Leyla');
  assert.equal(guestFromUrl('?id=x', ''), '');
  assert.equal(guestFromUrl('?g=%E2%80%AEevil', ''), 'evil');
});

test('selam satırı HTML kaçışlı, boş adda hiçbir şey', () => {
  assert.equal(guestHiHtml('', 'Dear {n},', esc), '');
  const h = guestHiHtml('<img src=x onerror=alert(1)>', 'Dear {n},', esc);
  assert.ok(!h.includes('<img'), h);
  assert.ok(h.includes('Dear <bdi>&lt;img src=x onerror=alert(1)&gt;</bdi>,'), h);
  assert.equal(guestHiHtml('Zeynep', 'Sevgili {n},', esc), '<p class="guest-hi">Sevgili <bdi>Zeynep</bdi>,</p>');
});
