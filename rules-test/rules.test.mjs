// Zarfla kural testleri — Firebase emülatöründe çalışır (CI "Kurallar" işi).
// Çalıştırma (depo kökünden):
//   npx firebase-tools emulators:exec --project demo-zarfla --only firestore,storage \
//     "node --test rules-test/rules.test.mjs"
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc,
} from 'firebase/firestore';
import { deleteObject, getMetadata, listAll, ref, uploadBytes } from 'firebase/storage';

// Sunucu fonksiyonunun (redeemPurchase) saf mantığı: ücretli belgeyi nasıl kurduğunu kurallarla sınamak için.
const serverLogic = createRequire(import.meta.url)('../functions/src/logic.js');

const PROJECT = 'demo-zarfla';
const H = 3600 * 1000;
const D = 24 * H;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  try {
    await env.clearStorage();
  } catch (_) {}
});

// ---- Dart'taki Invitation.toInviteData() ile aynı anahtar sırası ----
function dataJson(o = {}) {
  const d = {
    id: o.id ?? 'AbCdEf123456',
    type: o.type ?? 'nisan',
    theme: o.theme ?? 'papatya',
    lang: 'tr',
    layout: o.layout ?? 'klasik',
    opening: o.opening ?? 'door',
    n1: o.n1 ?? 'Test A',
    n2: o.n2 ?? 'Test B',
    host: '',
    msg: o.msg ?? 'Sizi aramızda görmek isteriz.',
    date: o.date ?? '2027-06-12',
    time: '19:00',
    end: '',
    venue: 'Test Venue',
    address: 'Avcılar / İstanbul',
    wa: '905551112233',
    program: [{ t: '19:00', x: 'Karşılama' }],
    notes: o.notes ?? [],
    ...(o.live ? { live: o.live } : {}),
    ...(o.gift ? { gift: o.gift } : {}),
    ...(o.music !== undefined ? { music: o.music } : {}),
    cover: o.cover ?? '',
    photos: o.photos ?? [],
    status: 'live',
    plan: o.plan ?? 'free',
  };
  return JSON.stringify(d);
}

const ID = 'AbCdEf123456';

function freeDoc(uid, o = {}) {
  const now = Date.now();
  const exp = o.expMs ?? now + 24 * H;
  const date = o.date ?? '2027-06-12';
  const n1 = o.n1 ?? 'Test A';
  const n2 = o.n2 ?? 'Test B';
  const theme = o.theme ?? 'papatya';
  const type = o.type ?? 'nisan';
  return {
    ownerUid: uid,
    schema: 1,
    data: o.data ?? dataJson({ id: o.dataId ?? ID, n1, n2, date, theme, type, plan: o.dataPlan ?? 'free' }),
    plan: 'free',
    status: 'live',
    createdAt: o.createdAt ?? serverTimestamp(),
    expiresAt: Timestamp.fromMillis(exp),
    deleteAt: Timestamp.fromMillis(exp + 30 * D),
    type,
    theme,
    n1,
    n2,
    date,
    origDate: o.origDate ?? date,
    nameEdits: o.nameEdits ?? 0,
    dateEdits: o.dateEdits ?? 0,
    ...(o.extra ?? {}),
  };
}

/** Kurallar kapalıyken belge yerleştir (ücretli ve süresi dolmuş durumlar için). */
async function seed(id, fields) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'invites', id), fields);
  });
}

function seededFree(uid, o = {}) {
  return { ...freeDoc(uid, o), createdAt: Timestamp.fromMillis(Date.now() - H) };
}

function seededPaid(uid, o = {}) {
  const exp = Date.now() + 365 * D;
  const date = o.date ?? '2027-06-12';
  const n1 = o.n1 ?? 'Test A';
  const theme = o.theme ?? 'altin';
  return {
    ...freeDoc(uid, { ...o, theme, n1, date, expMs: exp, dataPlan: 'premium' }),
    plan: 'paid',
    createdAt: Timestamp.fromMillis(Date.now() - H),
    origDate: o.origDate ?? date,
    nameEdits: o.nameEdits ?? 0,
    dateEdits: o.dateEdits ?? 0,
  };
}

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const st = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();
const inv = (uid, id = ID) => doc(db(uid), 'invites', id);

// ============================================================================
describe('Firestore · oluşturma', () => {
  test('C1 anonim kullanıcı geçerli ücretsiz belge oluşturur', async () => {
    await assertSucceeds(setDoc(inv('alice'), freeDoc('alice')));
  });
  test('C2 oturumsuz oluşturamaz', async () => {
    await assertFails(setDoc(inv(null), freeDoc('alice')));
  });
  test('C3 ownerUid başkası olamaz', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('bob')));
  });
  test('C4 istemci plan=paid yazamaz', async () => {
    await assertFails(setDoc(inv('alice'), { ...freeDoc('alice'), plan: 'paid' }));
  });
  test('C5 expiresAt yayın+25 saati aşamaz', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { expMs: Date.now() + 26 * H })));
  });
  test('C6 listede olmayan alan eklenemez', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { extra: { hack: 1 } })));
  });
  test('C7 nameEdits/dateEdits 0 olmalı', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { nameEdits: 1 })));
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { dateEdits: 1 })));
  });
  test('C8 origDate == date olmalı', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { origDate: '2027-01-01' })));
  });
  test('C9 ücretsiz planda ücretli tasarım yok', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { theme: 'altin' })));
  });
  test('C10 data içindeki id belge kimliğiyle aynı olmalı', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { dataId: 'ZZZZZZ123456' })));
  });
  test('C11 data içinde ikinci "theme" anahtarı (ezme hilesi) reddedilir', async () => {
    const d = dataJson({}).replace(/\}$/, ',"theme":"altin"}');
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d })));
  });
  test('C12 \\u0065 kaçışıyla anahtar gizleme reddedilir', async () => {
    const d = dataJson({}).replace(/\}$/, ',"th\\u0065me":"altin"}');
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d })));
  });
  test('C13 data.n1 üst düzey n1 ile aynı olmalı', async () => {
    const d = dataJson({ n1: 'Başka İsim' });
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d })));
  });
  test('C14 ücretsiz belgede data.plan "premium" olamaz (alt yazıyı gizleme)', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { dataPlan: 'premium' })));
  });
  test('C15 geçersiz kimlik (12 karakter değil) reddedilir', async () => {
    await assertFails(setDoc(inv('alice', 'kisa1'), freeDoc('alice', { dataId: 'kisa1' })));
  });
  test('C16 data ≥ 200 KB reddedilir', async () => {
    const d = dataJson({ msg: 'x'.repeat(205000) });
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d })));
  });
  test('C17 createdAt istemci saati olamaz (serverTimestamp şart)', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { createdAt: Timestamp.now() })));
  });
  test('C18 isimde çift tırnak reddedilir', async () => {
    const n1 = 'Pe"lin';
    const d = JSON.stringify({ ...JSON.parse(dataJson({})), n1 });
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { n1, data: d })));
  });
  test('C19 regex özel karakterli isim (ör. "A.B (C)+") kabul edilir', async () => {
    const n1 = 'A.B (C)+ [x]*';
    await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { n1 })));
  });
});

// ============================================================================
// Kurallarda tür/tasarım beyaz listesi YOK: yalnız anahtar biçimi ([a-z0-9]{1,24}) ve
// "ücretsiz plan yalnız papatya" denetlenir. Bu yüzden yeni tür/tasarım için kural değişikliği gerekmez.
const NEW_TYPES = ['nikah', 'asker', 'mevlit', 'mezuniyet', 'evacilisi', 'iftar', 'disbugdayi', 'cinsiyet', 'yildonumu', 'bekarliga', 'kurumsal'];
const NEW_THEMES = ['cini', 'kurugul', 'orman', 'kadife', 'gunbatimi', 'mevlit', 'monogram', 'sakayik', 'ayicik', 'pembebulut', 'uzay', 'safari', 'denizalti', 'prens', 'mezuniyet', 'yeniev'];
// Dalga 1: 10 yeni tasarım, 6 yeni açılış, "Ricalarımız" notları (data JSON'unda "notes").
const WAVE1_THEMES = ['fener', 'siyahbeyaz', 'limon', 'pampas', 'nar', 'safak', 'avize', 'sadu', 'kelebek', 'bugday'];
const WAVE1_OPENINGS = ['sarmasik', 'cicek', 'kurdele', 'kelebek', 'yildiz', 'pencere'];
const NOTES_MAX = ['Herkesin siyah giyinmesini rica ederiz.'.padEnd(140, 'a'), 'Hediye yerine "dualarınızı" bekliyoruz.', 'Lütfen 15 dakika önce yerinizde olunuz.', 'Tören sırasında fotoğraf çekmemenizi rica ederiz.'];

describe('Firestore · yeni türler ve tasarımlar', () => {
  for (const ty of NEW_TYPES) {
    test(`T1 yeni tür "${ty}" + papatya ile ücretsiz oluşturma geçer`, async () => {
      await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { type: ty })));
    });
  }
  for (const th of NEW_THEMES) {
    test(`T2 ücretsiz planda yeni tasarım "${th}" reddedilir`, async () => {
      await assertFails(setDoc(inv('alice'), freeDoc('alice', { theme: th })));
    });
  }
  test('T3 geçersiz biçimli tür (büyük harf, 25 karakter, tire) reddedilir', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { type: 'Nikah' })));
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { type: 'a'.repeat(25) })));
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { type: 'dis-bugdayi' })));
  });
  test('T4 ücretli yeni tasarım + yeni türde isim düzeltme geçer, tür/tasarım değişmez', async () => {
    const paid = (o = {}) => dataJson({ type: 'nikah', theme: 'kadife', plan: 'premium', ...o });
    await seed(ID, seededPaid('alice', { type: 'nikah', theme: 'kadife' }));
    await assertSucceeds(updateDoc(inv('alice'), { n1: 'Test A1', nameEdits: 1, data: paid({ n1: 'Test A1' }) }));
    await assertFails(updateDoc(inv('alice'), { theme: 'orman', data: paid({ theme: 'orman' }) }));
    await assertFails(updateDoc(inv('alice'), { type: 'asker', data: paid({ type: 'asker' }) }));
  });
});

// ============================================================================
describe('Firestore · Dalga 1 (yeni tasarım, açılış ve notlar)', () => {
  for (const th of WAVE1_THEMES) {
    test(`W1 ücretsiz planda dalga 1 tasarımı "${th}" reddedilir`, async () => {
      await assertFails(setDoc(inv('alice'), freeDoc('alice', { theme: th, data: dataJson({ theme: th }) })));
    });
  }
  for (const op of WAVE1_OPENINGS) {
    test(`W2 ücretsiz papatya + yeni açılış "${op}" + 4 not geçer`, async () => {
      const data = dataJson({ opening: op, notes: NOTES_MAX });
      await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { data })));
    });
  }
  test('W3 ücretli "nar" + "sarmasik" + 2 not: belge yerleştirilir, notlar/açılış güncellenir, tasarım değişmez', async () => {
    const notes = ['Hediye yerine dualarınızı bekliyoruz.', 'Lütfen 15 dakika önce yerinizde olunuz.'];
    const paid = (o = {}) => dataJson({ theme: 'nar', plan: 'premium', opening: 'sarmasik', notes, ...o });
    await seed(ID, seededPaid('alice', { theme: 'nar', data: paid() }));
    await assertSucceeds(getDoc(inv(null)));
    // yalnız notlar + açılış değişir (kilitli alanlara dokunulmaz)
    await assertSucceeds(updateDoc(inv('alice'), { data: paid({ opening: 'cicek', notes: NOTES_MAX }) }));
    // tasarım kilidi sürer
    await assertFails(updateDoc(inv('alice'), { theme: 'bugday', data: paid({ theme: 'bugday' }) }));
  });
  test('W4 ücretsiz "nar" 2 notla yine reddedilir', async () => {
    const data = dataJson({ theme: 'nar', opening: 'sarmasik', notes: ['Hediye yerine dualarınızı bekliyoruz.', 'Lütfen 15 dakika önce yerinizde olunuz.'] });
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { theme: 'nar', data })));
  });
});

// ============================================================================
describe('Firestore · okuma', () => {
  test('R1 herkes yayındaki belgeyi okur (get)', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(getDoc(inv(null)));
  });
  test('R2 süresi dolan belgeyi oturumsuz okuyamaz', async () => {
    await seed(ID, seededFree('alice', { expMs: Date.now() - H }));
    await assertFails(getDoc(inv(null)));
    await assertFails(getDoc(inv('bob')));
  });
  test('R3 sahibi süresi dolan belgesini okuyabilir', async () => {
    await seed(ID, seededFree('alice', { expMs: Date.now() - H }));
    await assertSucceeds(getDoc(inv('alice')));
  });
  test('R4 olmayan belge: okuma izni var (yok bilgisi)', async () => {
    await assertSucceeds(getDoc(inv(null, 'Yok123456789')));
  });
  test('R5 listeleme kimseye açık değil', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(getDocs(collection(db(null), 'invites')));
    await assertFails(getDocs(collection(db('alice'), 'invites')));
  });
});

// ============================================================================
describe('Firestore · canlı yayın bağlantısı ve hediye IBAN\'ı', () => {
  const GIFT = { holder: 'Ali Demir', iban: 'TR330006100519786457841326', bank: 'Örnek Banka' };
  const LIVE = { url: 'https://youtu.be/abc123', note: 'Yayın 19:00\'da başlar' };
  const premiumGift = (o = {}) => dataJson({ theme: 'altin', plan: 'premium', gift: GIFT, ...o });

  test('G1 ücretsiz oluşturma: data içinde "iban" anahtarı reddedilir', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ gift: GIFT }) })));
  });
  test('G2 ücretsiz oluşturma: canlı yayın bağlantısı serbest', async () => {
    await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ live: LIVE }) })));
  });
  test('G3 ücretsiz güncelleme: IBAN eklenemez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('alice'), { data: dataJson({ gift: GIFT }) }));
  });
  test('G4 ücretsiz güncelleme: canlı yayın bağlantısı eklenebilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { data: dataJson({ live: LIVE }) }));
  });
  test('G5 ücretsiz: not metninde "iban" sözcüğü geçmesi sorun değil (anahtar değil)', async () => {
    await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ notes: ['IBAN için bize yazın'] }) })));
  });
  test('G6 ücretsiz: "iban" anahtarı \\u0069ban kaçışıyla gizlenemez', async () => {
    const d = dataJson({}).replace('"status":"live"', '"\\u0069ban":"TR330006100519786457841326","status":"live"');
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d })));
  });
  test('G7 ücretsiz: "iban" anahtarı boşluklu yazılsa da (\"iban\" :) reddedilir', async () => {
    const d = dataJson({}).replace('"status":"live"', '"gift":{"iban" : "TR330006100519786457841326"},"status":"live"');
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d })));
  });
  test('G8 ücretli güncelleme: IBAN + canlı yayın eklenebilir', async () => {
    await seed(ID, seededPaid('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { data: premiumGift({ live: LIVE }) }));
  });
  test('G9 ücretli: IBAN sonradan kaldırılabilir', async () => {
    await seed(ID, { ...seededPaid('alice'), data: premiumGift() });
    await assertSucceeds(updateDoc(inv('alice'), { data: dataJson({ theme: 'altin', plan: 'premium' }) }));
  });
  test('G10 sunucunun (redeemPurchase) kurduğu ücretli belge live+gift alanlarını aynen korur ve sahibi güncelleyebilir', async () => {
    const built = serverLogic.buildPaidData(premiumGift({ live: LIVE }), ID);
    const o = JSON.parse(built.data);
    assert.deepEqual(o.gift, GIFT);
    assert.deepEqual(o.live, LIVE);
    const t = serverLogic.paidTimes(Date.now());
    await seed(ID, {
      ownerUid: 'alice', schema: 1, data: built.data, plan: 'paid', status: 'live',
      createdAt: Timestamp.fromMillis(Date.now()), expiresAt: Timestamp.fromMillis(t.expiresAtMs),
      deleteAt: Timestamp.fromMillis(t.deleteAtMs), ...built.lock,
    });
    const next = { ...o, gift: { ...GIFT, bank: 'Başka Banka' } };
    await assertSucceeds(updateDoc(inv('alice'), { data: JSON.stringify(next) }));
  });
});

// ============================================================================
describe('Firestore · arka plan müziği (yalnız ücretli)', () => {
  const premiumMusic = (o = {}) => dataJson({ theme: 'altin', plan: 'premium', music: 'dugun-wagner', ...o });

  test('M1 ücretsiz oluşturma: data içinde "music" anahtarı reddedilir', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ music: 'dugun-wagner' }) })));
  });
  test('M2 ücretsiz güncelleme: müzik eklenemez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('alice'), { data: dataJson({ music: 'kutlama-joplin' }) }));
  });
  test('M3 ücretsiz: not metninde "music" sözcüğü sorun değil (anahtar değil)', async () => {
    await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ notes: ['"music": lütfen getirin'] }) })));
  });
  test('M4 ücretsiz: "music" anahtarı \\u006dusic kaçışıyla ya da boşlukla gizlenemez', async () => {
    const d1 = dataJson({}).replace('"status":"live"', '"\\u006dusic":"dugun-wagner","status":"live"');
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d1 })));
    const d2 = dataJson({}).replace('"status":"live"', '"music" : "dugun-wagner","status":"live"');
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { data: d2 })));
  });
  test('M5 ücretli güncelleme: müzik eklenebilir, değiştirilebilir, kaldırılabilir', async () => {
    await seed(ID, seededPaid('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { data: premiumMusic() }));
    await assertSucceeds(updateDoc(inv('alice'), { data: premiumMusic({ music: 'klasik-grieg' }) }));
    await assertSucceeds(updateDoc(inv('alice'), { data: dataJson({ theme: 'altin', plan: 'premium' }) }));
  });
  test('M6 ücretli: geçersiz müzik değeri (adres, büyük harf, boş, çift anahtar) reddedilir', async () => {
    await seed(ID, seededPaid('alice'));
    for (const m of ['https://evil.example/a.mp3', '../x', 'Dugun', '', 'a'.repeat(41)]) {
      await assertFails(updateDoc(inv('alice'), { data: premiumMusic({ music: m }) }));
    }
    const dup = premiumMusic().replace('"status":"live"', '"music":"klasik-grieg","status":"live"');
    await assertFails(updateDoc(inv('alice'), { data: dup }));
  });
  test('M7 sunucunun (redeemPurchase) kurduğu ücretli belge müziği aynen korur', async () => {
    const built = serverLogic.buildPaidData(premiumMusic(), ID);
    assert.equal(JSON.parse(built.data).music, 'dugun-wagner');
    const t = serverLogic.paidTimes(Date.now());
    await seed(ID, {
      ownerUid: 'alice', schema: 1, data: built.data, plan: 'paid', status: 'live',
      createdAt: Timestamp.fromMillis(Date.now()), expiresAt: Timestamp.fromMillis(t.expiresAtMs),
      deleteAt: Timestamp.fromMillis(t.deleteAtMs), ...built.lock,
    });
    await assertSucceeds(updateDoc(inv('alice'), { data: built.data.replace('"dugun-wagner"', '"kutlama-funky"') }));
  });
});

// ============================================================================
describe('Firestore · güncelleme (ücretsiz)', () => {
  test('U1 sahibi metni ve isimleri güncelleyebilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(updateDoc(inv('alice'), {
      data: dataJson({ n1: 'Test A1', msg: 'Yeni mesaj' }), n1: 'Test A1',
    }));
  });
  test('U2 başkası güncelleyemez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('bob'), { data: dataJson({ msg: 'hack' }) }));
  });
  test('U3 süre uzatılamaz', async () => {
    const exp = Date.now() + 20 * H;
    await seed(ID, seededFree('alice', { expMs: exp }));
    await assertFails(updateDoc(inv('alice'), { expiresAt: Timestamp.fromMillis(exp + D) }));
  });
  test('U4 plan değiştirilemez (free → paid)', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('alice'), { plan: 'paid', data: dataJson({ plan: 'premium' }) }));
  });
  test('U5 origDate, ownerUid, schema, createdAt değişmez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('alice'), { origDate: '2027-06-13' }));
    await assertFails(updateDoc(inv('alice'), { schema: 2 }));
    await assertFails(updateDoc(inv('alice'), { createdAt: Timestamp.now() }));
    await assertFails(updateDoc(inv('alice'), { ownerUid: 'bob' }));
  });
  test('U6 ücretsizde sayaçlar değişmez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('alice'), { nameEdits: 1 }));
  });
  test('U7 ücretsizde tarih serbestçe değişir (data ile birlikte)', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { date: '2027-12-01', data: dataJson({ date: '2027-12-01' }) }));
  });
  test('U8 data ile üst düzey alan uyumsuzsa reddedilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(updateDoc(inv('alice'), { data: dataJson({ date: '2027-12-01' }) }));
  });
});

// ============================================================================
describe('Firestore · güncelleme (ücretli kilitler)', () => {
  const paidData = (o = {}) => dataJson({ theme: 'altin', plan: 'premium', ...o });

  test('P1 isim düzeltme: nameEdits tam +1 ile geçer', async () => {
    await seed(ID, seededPaid('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { n1: 'Test A1', nameEdits: 1, data: paidData({ n1: 'Test A1' }) }));
  });
  test('P2 sayaç artmadan isim değişmez', async () => {
    await seed(ID, seededPaid('alice'));
    await assertFails(updateDoc(inv('alice'), { n1: 'Test A1', data: paidData({ n1: 'Test A1' }) }));
  });
  test('P3 sayaç +2 olamaz', async () => {
    await seed(ID, seededPaid('alice'));
    await assertFails(updateDoc(inv('alice'), { n1: 'Test A1', nameEdits: 2, data: paidData({ n1: 'Test A1' }) }));
  });
  test('P4 3 hak bitince isim değişmez', async () => {
    await seed(ID, seededPaid('alice', { nameEdits: 3 }));
    await assertFails(updateDoc(inv('alice'), { n1: 'Test A1', nameEdits: 4, data: paidData({ n1: 'Test A1' }) }));
  });
  test('P5 tasarım ve tür değişmez', async () => {
    await seed(ID, seededPaid('alice'));
    await assertFails(updateDoc(inv('alice'), { theme: 'kina', data: paidData({ theme: 'kina' }) }));
    await assertFails(updateDoc(inv('alice'), { type: 'dugun', data: paidData({ type: 'dugun' }) }));
  });
  test('P6 tarih +30 gün, dateEdits +1 ile geçer', async () => {
    await seed(ID, seededPaid('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { date: '2027-07-12', dateEdits: 1, data: paidData({ date: '2027-07-12' }) }));
  });
  test('P7 tarih ±60 günü aşamaz (61 gün)', async () => {
    await seed(ID, seededPaid('alice'));
    await assertFails(updateDoc(inv('alice'), { date: '2027-08-12', dateEdits: 1, data: paidData({ date: '2027-08-12' }) }));
  });
  test('P8 tarih tam -60 gün geçer', async () => {
    await seed(ID, seededPaid('alice'));
    await assertSucceeds(updateDoc(inv('alice'), { date: '2027-04-13', dateEdits: 1, data: paidData({ date: '2027-04-13' }) }));
  });
  test('P9 2 tarih hakkı bitince değişmez', async () => {
    await seed(ID, seededPaid('alice', { date: '2027-06-20', origDate: '2027-06-12', dateEdits: 2 }));
    await assertFails(updateDoc(inv('alice'), { date: '2027-06-21', dateEdits: 3, data: paidData({ date: '2027-06-21' }) }));
  });
  test('P10 ücretli süre de istemciden uzatılamaz', async () => {
    const p = seededPaid('alice');
    await seed(ID, p);
    await assertFails(updateDoc(inv('alice'), { expiresAt: Timestamp.fromMillis(p.expiresAt.toMillis() + D) }));
  });
});

// ============================================================================
describe('Firestore · silme', () => {
  test('D1 sahibi siler', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(deleteDoc(inv('alice')));
  });
  test('D2 başkası/oturumsuz silemez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(deleteDoc(inv('bob')));
    await assertFails(deleteDoc(inv(null)));
  });
});

// ============================================================================
// Aşama 3: ücretli plan yalnız sunucu fonksiyonundan; istemci "paid" oluşturamaz/yükseltemez.
describe('Firestore · Aşama 3 (ödeme, sunucu yazımı, users/purchases)', () => {
  const premiumData = (o = {}) => dataJson({ theme: 'altin', plan: 'premium', ...o });

  test('C20 ücretsiz expiresAt yayın+24s10dk üstü reddedilir', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { expMs: Date.now() + 24 * H + 30 * 60 * 1000 })));
  });
  test('C21 ücretsiz expiresAt geçmişte olamaz', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { expMs: Date.now() - 60 * 1000 })));
  });
  test('C22 tutarlı ücretli belge (plan paid, data premium, 365 gün) istemciden oluşturulamaz', async () => {
    const exp = Date.now() + 365 * D;
    const paid = {
      ...freeDoc('alice', { theme: 'altin', expMs: exp, dataPlan: 'premium' }),
      plan: 'paid',
    };
    await assertFails(setDoc(inv('alice'), paid));
  });
  test('U9 ücretsizden ücretliye tam tutarlı yükseltme bile reddedilir', async () => {
    const f = seededFree('alice');
    await seed(ID, f);
    await assertFails(updateDoc(inv('alice'), { plan: 'paid', theme: 'altin', data: premiumData() }));
  });
  test('PD1 sunucunun (redeemPurchase) yazdığı ücretli belgeyi sahibi fotoğraf URL\'leri ve isim düzeltmesiyle güncelleyebilir', async () => {
    const built = serverLogic.buildPaidData(dataJson({ theme: 'nar', plan: 'premium', notes: ['Lütfen 15 dakika önce yerinizde olunuz.'] }), ID);
    const t = serverLogic.paidTimes(Date.now());
    await seed(ID, {
      ownerUid: 'alice', schema: 1, data: built.data, plan: 'paid', status: 'live',
      createdAt: Timestamp.fromMillis(Date.now()), expiresAt: Timestamp.fromMillis(t.expiresAtMs),
      deleteAt: Timestamp.fromMillis(t.deleteAtMs), ...built.lock,
    });
    await assertSucceeds(getDoc(inv(null)));
    const withPhotos = JSON.parse(built.data);
    withPhotos.cover = 'https://firebasestorage.googleapis.com/v0/b/x/o/invites%2FAbCdEf123456%2Fcover.jpg?alt=media';
    withPhotos.photos = ['https://firebasestorage.googleapis.com/v0/b/x/o/invites%2FAbCdEf123456%2Fg1.jpg?alt=media'];
    await assertSucceeds(updateDoc(inv('alice'), { data: JSON.stringify(withPhotos) }));
    const renamed = { ...withPhotos, n1: 'Test A1' };
    await assertSucceeds(updateDoc(inv('alice'), { n1: 'Test A1', nameEdits: 1, data: JSON.stringify(renamed) }));
    // tasarım kilidi sunucu belgesinde de geçerli
    await assertFails(updateDoc(inv('alice'), { theme: 'altin', data: JSON.stringify({ ...renamed, theme: 'altin' }) }));
  });
  test('US1 kullanıcı yalnız kendi users belgesini okur, kimse yazamaz', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users', 'alice'), { premium: true });
    });
    await assertSucceeds(getDoc(doc(db('alice'), 'users', 'alice')));
    await assertFails(getDoc(doc(db('bob'), 'users', 'alice')));
    await assertFails(getDoc(doc(db(null), 'users', 'alice')));
    await assertFails(setDoc(doc(db('alice'), 'users', 'alice'), { premium: true }));
    await assertFails(getDocs(collection(db('alice'), 'users')));
  });
  test('PU1 purchases koleksiyonu istemciye tamamen kapalı', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'purchases', 'h1'), { uid: 'alice' });
    });
    await assertFails(getDoc(doc(db('alice'), 'purchases', 'h1')));
    await assertFails(setDoc(doc(db('alice'), 'purchases', 'h2'), { uid: 'alice' }));
  });
  test('CR1 credits: sahibi kendi bakiyesini okur; başkası/oturumsuz okuyamaz; listelenemez', async () => {
    const c = serverLogic.applyGrant(null, { h: 'h1', productId: 'zarfla_invite_3', rights: 3, nowMs: Date.now() });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'credits', 'alice'), c);
    });
    const s = await assertSucceeds(getDoc(doc(db('alice'), 'credits', 'alice')));
    assert.equal(s.data().balance, 3);
    await assertFails(getDoc(doc(db('bob'), 'credits', 'alice')));
    await assertFails(getDoc(doc(db(null), 'credits', 'alice')));
    await assertFails(getDocs(collection(db('alice'), 'credits')));
  });
  test('CR2 credits: istemci bakiye oluşturamaz, artıramaz, silemez', async () => {
    await assertFails(setDoc(doc(db('alice'), 'credits', 'alice'), { balance: 3, lots: [], ledger: [] }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'credits', 'alice'), { balance: 1, lots: [], ledger: [] });
    });
    await assertFails(updateDoc(doc(db('alice'), 'credits', 'alice'), { balance: 99 }));
    await assertFails(setDoc(doc(db('bob'), 'credits', 'bob'), { balance: 99 }));
    await assertFails(deleteDoc(doc(db('alice'), 'credits', 'alice')));
  });
  test('CR3 paket hakkıyla sunucunun (useCredit) yazdığı ücretli belge kurallara uyar ve sahibi güncelleyebilir', async () => {
    const built = serverLogic.buildPaidData(dataJson({ theme: 'altin', plan: 'premium' }), ID);
    const t = serverLogic.paidTimes(Date.now());
    await seed(ID, {
      ownerUid: 'alice', schema: 1, data: built.data, plan: 'paid', status: 'live',
      createdAt: Timestamp.fromMillis(Date.now()), expiresAt: Timestamp.fromMillis(t.expiresAtMs),
      deleteAt: Timestamp.fromMillis(t.deleteAtMs), ...built.lock,
    });
    const o = JSON.parse(built.data);
    await assertSucceeds(updateDoc(inv('alice'), { data: JSON.stringify({ ...o, msg: 'Yeni mesaj' }) }));
  });
});

// ============================================================================
// stats/**: günlük özet sayımları yalnız sunucuya (Admin) açık; istemci okuyamaz, yazamaz, listeleyemez.
describe('Firestore · quota (yalnız sunucu, N-1)', () => {
  test('QU1 istemci quota/{uid} okuyamaz, yazamaz, sıfırlayamaz, silemez, listeleyemez', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'quota', 'alice'), { day: '2026-11-22', dayCount: 20 });
    });
    await assertFails(getDoc(doc(db('alice'), 'quota', 'alice')));
    await assertFails(getDoc(doc(db(null), 'quota', 'alice')));
    await assertFails(setDoc(doc(db('alice'), 'quota', 'alice'), { day: '2026-11-22', dayCount: 0 }));
    await assertFails(updateDoc(doc(db('alice'), 'quota', 'alice'), { dayCount: 0 }));
    await assertFails(setDoc(doc(db('bob'), 'quota', 'bob'), { day: '2026-11-22', dayCount: 0 }));
    await assertFails(deleteDoc(doc(db('alice'), 'quota', 'alice')));
    await assertFails(getDocs(collection(db('alice'), 'quota')));
  });
});

describe('Firestore · stats (yalnız sunucu)', () => {
  const DAY = ['stats', 'daily', 'days', '2026-11-14'];

  test('ST1 stats belgesi oturumsuz, anonim ve belge sahibi dahil hiçbir istemciye açık değil', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), ...DAY), { schema: 1, day: '2026-11-14', invitations: { created: 3 } });
    });
    for (const uid of [null, 'alice', 'bob']) {
      await assertFails(getDoc(doc(db(uid), ...DAY)), `okuma ${uid}`);
      await assertFails(setDoc(doc(db(uid), 'stats', 'daily', 'days', '2026-11-15'), { schema: 1 }), `yazma ${uid}`);
      await assertFails(updateDoc(doc(db(uid), ...DAY), { schema: 2 }), `güncelleme ${uid}`);
      await assertFails(deleteDoc(doc(db(uid), ...DAY)), `silme ${uid}`);
      await assertFails(getDocs(collection(db(uid), 'stats', 'daily', 'days')), `liste ${uid}`);
      await assertFails(getDoc(doc(db(uid), 'stats', 'daily')), `üst belge ${uid}`);
    }
  });
});

// ============================================================================
describe('Storage', () => {
  const jpg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
  const meta = { contentType: 'image/jpeg' };
  const fref = (uid, file, id = ID) => ref(st(uid), `invites/${id}/${file}`);

  test('S1 sahibi kapak yükler', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(uploadBytes(fref('alice', 'cover.jpg'), jpg, meta));
    await assertSucceeds(uploadBytes(fref('alice', 'g6.webp'), jpg, { contentType: 'image/webp' }));
  });
  test('S2 başkası yükleyemez', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('bob', 'cover.jpg'), jpg, meta));
    await assertFails(uploadBytes(fref(null, 'cover.jpg'), jpg, meta));
  });
  test('S3 belge yokken yüklenemez', async () => {
    await assertFails(uploadBytes(fref('alice', 'cover.jpg', 'Yok123456789'), jpg, meta));
  });
  test('S4 görüntü olmayan içerik türü reddedilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('alice', 'cover.jpg'), jpg, { contentType: 'text/plain' }));
  });
  test('S5 izinsiz dosya adı reddedilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('alice', 'g7.jpg'), jpg, meta));
    await assertFails(uploadBytes(fref('alice', 'evil.html'), jpg, meta));
  });
  test('S6 2 MB ve üzeri reddedilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('alice', 'cover.jpg'), new Uint8Array(2 * 1024 * 1024), meta));
  });
  test('S7 herkes okur; yalnız sahibi siler', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(uploadBytes(fref('alice', 'g1.jpg'), jpg, meta));
    await assertSucceeds(getMetadata(fref(null, 'g1.jpg')));
    await assertFails(deleteObject(fref('bob', 'g1.jpg')));
    await assertSucceeds(deleteObject(fref('alice', 'g1.jpg')));
  });
  // ---- Güvenlik denetimi M-3 ----
  test('S8 SVG/GIF/HTML içerik türü reddedilir (uzantı .png olsa da)', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('alice', 'cover.png'), jpg, { contentType: 'image/svg+xml' }));
    await assertFails(uploadBytes(fref('alice', 'cover.png'), jpg, { contentType: 'image/gif' }));
    await assertFails(uploadBytes(fref('alice', 'cover.gif'), jpg, { contentType: 'image/gif' }));
    await assertFails(uploadBytes(fref('alice', 'cover.jpg'), jpg, { contentType: 'text/html' }));
    await assertFails(uploadBytes(fref('alice', 'cover.svg'), jpg, { contentType: 'image/svg+xml' }));
  });
  test('S9 uzantı ile içerik türü eşleşmeli; jpeg/png/webp kabul', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('alice', 'g1.png'), jpg, { contentType: 'image/jpeg' }));
    await assertFails(uploadBytes(fref('alice', 'g2.jpg'), jpg, { contentType: 'image/webp' }));
    await assertSucceeds(uploadBytes(fref('alice', 'g1.jpeg'), jpg, { contentType: 'image/jpeg' }));
    await assertSucceeds(uploadBytes(fref('alice', 'g2.png'), jpg, { contentType: 'image/png' }));
    await assertSucceeds(uploadBytes(fref('alice', 'g3.webp'), jpg, { contentType: 'image/webp' }));
  });
  test('S10 boş dosya reddedilir; 2 MB altı kabul', async () => {
    await seed(ID, seededFree('alice'));
    await assertFails(uploadBytes(fref('alice', 'cover.jpg'), new Uint8Array(0), meta));
    await assertSucceeds(uploadBytes(fref('alice', 'cover.jpg'), new Uint8Array(2 * 1024 * 1024 - 1), meta));
  });
  test('S11 klasör listeleme: herkese kapalı, yalnız sahibi (silme temizliği)', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(uploadBytes(fref('alice', 'g1.jpg'), jpg, meta));
    await assertFails(listAll(ref(st(null), `invites/${ID}`)));
    await assertFails(listAll(ref(st('bob'), `invites/${ID}`)));
    await assertFails(listAll(ref(st('bob'), 'invites')));
    await assertSucceeds(listAll(ref(st('alice'), `invites/${ID}`)));
  });
  test('S12 süresi dolmuş davetiyeye yükleme yok; sahibi yine de silebilir', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), `invites/${ID}/g1.jpg`), jpg, meta);
    });
    await seed(ID, seededFree('alice', { expMs: Date.now() - H }));
    await assertFails(uploadBytes(fref('alice', 'cover.jpg'), jpg, meta));
    await assertSucceeds(deleteObject(fref('alice', 'g1.jpg')));
  });
  test('S13 ücretli (1 yıl) davetiyeye sahibi yükler, başkası okur ama yazamaz', async () => {
    await seed(ID, seededPaid('alice'));
    await assertSucceeds(uploadBytes(fref('alice', 'cover.webp'), jpg, { contentType: 'image/webp' }));
    await assertSucceeds(getMetadata(fref('bob', 'cover.webp')));
    await assertFails(uploadBytes(fref('bob', 'cover.webp'), jpg, { contentType: 'image/webp' }));
  });
});

// ============================================================================
// Dalga 3: 6 yeni düzen + 8 yeni açılış. Kurallarda düzen/açılış beyaz listesi yok; ikisi de
// mevcutlar gibi tüm planlarda serbest (ücretli olan yalnız tasarım/tema).
const WAVE3_LAYOUTS = ['galeri', 'mektup', 'davetkarti', 'minimal', 'gece', 'hikaye'];
const WAVE3_OPENINGS = ['zarfacil', 'muhurkir', 'kagitkatla', 'parilti', 'lale', 'fener', 'kapikemer', 'konfeti'];

describe('Firestore · Dalga 3 (yeni düzen ve açılışlar)', () => {
  for (const lay of WAVE3_LAYOUTS) {
    test(`X1 ücretsiz papatya + yeni düzen "${lay}" geçer`, async () => {
      await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ layout: lay }) })));
    });
  }
  for (const op of WAVE3_OPENINGS) {
    test(`X2 ücretsiz papatya + yeni açılış "${op}" geçer`, async () => {
      await assertSucceeds(setDoc(inv('alice'), freeDoc('alice', { data: dataJson({ opening: op }) })));
    });
  }
  test('X3 yeni düzen/açılış ile de ücretsiz planda ücretli tasarım reddedilir', async () => {
    await assertFails(setDoc(inv('alice'), freeDoc('alice', { theme: 'altin', data: dataJson({ theme: 'altin', layout: 'gece', opening: 'kapikemer' }) })));
  });
  test('X4 ücretli belgede düzen + açılış dalga 3 değerlerine güncellenir, tasarım değişmez', async () => {
    const paid = (o = {}) => dataJson({ theme: 'nar', plan: 'premium', ...o });
    await seed(ID, seededPaid('alice', { theme: 'nar', data: paid() }));
    await assertSucceeds(updateDoc(inv('alice'), { data: paid({ layout: 'hikaye', opening: 'fener' }) }));
    await assertFails(updateDoc(inv('alice'), { theme: 'altin', data: paid({ theme: 'altin', layout: 'mektup' }) }));
  });
});
