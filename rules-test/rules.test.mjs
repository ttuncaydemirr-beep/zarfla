// Zarfla kural testleri — Firebase emülatöründe çalışır (CI "Kurallar" işi).
// Çalıştırma (depo kökünden):
//   npx firebase-tools emulators:exec --project demo-zarfla --only firestore,storage \
//     "node --test rules-test/rules.test.mjs"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc,
} from 'firebase/firestore';
import { deleteObject, getMetadata, ref, uploadBytes } from 'firebase/storage';

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
    layout: 'klasik',
    opening: 'door',
    n1: o.n1 ?? 'Pelin Su',
    n2: o.n2 ?? 'Burak',
    host: '',
    msg: o.msg ?? 'Sizi aramızda görmek isteriz.',
    date: o.date ?? '2027-06-12',
    time: '19:00',
    end: '',
    venue: 'Baler Garden',
    address: 'Avcılar / İstanbul',
    wa: '905551112233',
    program: [{ t: '19:00', x: 'Karşılama' }],
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
  const n1 = o.n1 ?? 'Pelin Su';
  const n2 = o.n2 ?? 'Burak';
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
  const n1 = o.n1 ?? 'Pelin Su';
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
describe('Firestore · güncelleme (ücretsiz)', () => {
  test('U1 sahibi metni ve isimleri güncelleyebilir', async () => {
    await seed(ID, seededFree('alice'));
    await assertSucceeds(updateDoc(inv('alice'), {
      data: dataJson({ n1: 'Pelin', msg: 'Yeni mesaj' }), n1: 'Pelin',
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
    await assertSucceeds(updateDoc(inv('alice'), { n1: 'Pelin', nameEdits: 1, data: paidData({ n1: 'Pelin' }) }));
  });
  test('P2 sayaç artmadan isim değişmez', async () => {
    await seed(ID, seededPaid('alice'));
    await assertFails(updateDoc(inv('alice'), { n1: 'Pelin', data: paidData({ n1: 'Pelin' }) }));
  });
  test('P3 sayaç +2 olamaz', async () => {
    await seed(ID, seededPaid('alice'));
    await assertFails(updateDoc(inv('alice'), { n1: 'Pelin', nameEdits: 2, data: paidData({ n1: 'Pelin' }) }));
  });
  test('P4 3 hak bitince isim değişmez', async () => {
    await seed(ID, seededPaid('alice', { nameEdits: 3 }));
    await assertFails(updateDoc(inv('alice'), { n1: 'Pelin', nameEdits: 4, data: paidData({ n1: 'Pelin' }) }));
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
});
