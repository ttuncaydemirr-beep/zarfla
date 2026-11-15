// Davetli sayfasındaki (assets/invite/invite.html) IBAN / canlı yayın doğrulayıcılarının Node birim testi.
// Çalıştırma: node --test test/js/live_iban.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../../assets/invite/invite.html', import.meta.url), 'utf8');
const a = html.indexOf('/*LIVEGIFT-BEGIN*/');
const b = html.indexOf('/*LIVEGIFT-END*/');
assert.ok(a > 0 && b > a, 'LIVEGIFT bloğu bulunamadı');
const ctx = { URL };
vm.createContext(ctx);
vm.runInContext(html.slice(a, b) + '\nthis.api={ibanValid,ibanClean,ibanFmt,liveUrlOk,cleanLive,cleanGift,IBAN_LEN};', ctx);
const { ibanValid, ibanFmt, liveUrlOk, IBAN_LEN } = ctx.api;
// vm bağlamından gelen nesneler başka bir gerçekleme alanında olduğundan JSON üzerinden karşılaştırılır
const cleanLive = (x) => JSON.parse(JSON.stringify(ctx.api.cleanLive(x)));
const cleanGift = (x, p) => JSON.parse(JSON.stringify(ctx.api.cleanGift(x, p)));

const VALID = [
  'TR330006100519786457841326', 'DE89370400440532013000', 'AT611904300234573201', 'CH9300762011623852957',
  'NL91ABNA0417164300', 'BE68539007547034', 'FR1420041010050500013M02606', 'GB82WEST12345698765432',
  'SA0380000000608010167519', 'AE070331234567890123456', 'QA58DOHB00001234567890ABCDEFG',
  'KW81CBKU0000000000001234560101', 'BH67BMAG00001299123456', 'IT60X0542811101000000123456',
  'ES9121000418450200051332',
];

test('geçerli IBAN örnekleri (bitişik, boşluklu, küçük harf, tireli)', () => {
  for (const v of VALID) {
    assert.ok(ibanValid(v), v);
    assert.ok(ibanValid(ibanFmt(v)), v);
    assert.ok(ibanValid(v.toLowerCase()), v);
  }
  assert.ok(ibanValid('TR33-0006-1005-1978-6457-8413-26'));
});

test('geçersiz IBAN: sağlama toplamı, uzunluk, ülke, biçim', () => {
  for (const v of ['TR330006100519786457841327', 'DE89370400440532013001', 'TR33000610051978645784132',
    'TR3300061005197864578413260', 'XX89370400440532013000', '1234567890', '', 'DE89 3704 0044 0532 0130 0!', null, undefined]) {
    assert.equal(ibanValid(v), false, String(v));
  }
});

test('ibanFmt 4\'lü gruplar', () => {
  assert.equal(ibanFmt('tr330006100519786457841326'), 'TR33 0006 1005 1978 6457 8413 26');
  assert.equal(ibanFmt('DE89370400440532013000'), 'DE89 3704 0044 0532 0130 00');
});

test('uzunluk tablosu: ülke sayısı ve ana ülkeler', () => {
  for (const [c, n] of Object.entries({ TR: 26, DE: 22, AT: 20, CH: 21, NL: 18, BE: 16, FR: 27, GB: 22, SA: 24, AE: 23, QA: 29, KW: 30, BH: 22 })) assert.equal(IBAN_LEN[c], n, c);
  assert.ok(Object.keys(IBAN_LEN).length >= 80);
});

test('canlı yayın bağlantısı: https tamam; javascript:/data:/http/bozuk reddedilir', () => {
  for (const u of ['https://www.youtube.com/watch?v=abc', 'https://zoom.us/j/123?pwd=a', 'https://meet.google.com/abc-defg-hij', 'https://www.tiktok.com/@x/live', 'https://www.instagram.com/live/x/'])
    assert.equal(liveUrlOk(u), u);
  assert.equal(liveUrlOk('  https://youtu.be/a  '), 'https://youtu.be/a');
  for (const u of ['', 'http://youtu.be/a', 'javascript:alert(1)', 'JaVaScRiPt:alert(1)', 'data:text/html,<b>x</b>', 'ftp://a.com', '//a.com', 'a.com',
    'https://', 'https://localhost/a', 'https://u:p@a.com/x', 'https://a.com/a b', 'https://a.com/"x', 'https://a.com/<x>', 'https://a.com/\\x', 'https://a.com/\u0000', null, 5])
    assert.equal(liveUrlOk(u), '', String(u));
  assert.equal(liveUrlOk('https://a.com/' + 'x'.repeat(286)), 'https://a.com/' + 'x'.repeat(286)); // 300
  assert.equal(liveUrlOk('https://a.com/' + 'x'.repeat(287)), ''); // 301
});

test('cleanLive / cleanGift: ücretsizde IBAN asla; eksik bilgi yok sayılır', () => {
  assert.deepEqual(cleanLive({ url: 'https://youtu.be/a', note: ' Yayın\n19:00 ' }), { url: 'https://youtu.be/a', note: 'Yayın 19:00' });
  assert.equal(cleanLive({ url: 'javascript:1' }), null);
  assert.equal(cleanLive(undefined), null);
  const g = { holder: ' Ali Demir ', iban: 'tr33 0006 1005 1978 6457 8413 26', bank: 'Banka' };
  assert.deepEqual(cleanGift(g, true), { holder: 'Ali Demir', iban: 'TR330006100519786457841326', bank: 'Banka' });
  assert.equal(cleanGift(g, false), null);
  assert.equal(cleanGift({ ...g, holder: '  ' }, true), null);
  assert.equal(cleanGift({ ...g, iban: 'TR330006100519786457841327' }, true), null);
  assert.equal(cleanGift(null, true), null);
});
