'use strict';

// Zarfla — sunucu fonksiyonlarının SAF mantığı (Firebase'e bağımlı değil; test/ altında birim testli).
// Veri sözleşmesi: lib/cloud/invite_contract.dart · Kurallar: firestore.rules (dataOk / fieldsOk).

const crypto = require('node:crypto');

const PACKAGE_NAME = 'com.demirgamesstudio.zarfla';
const PRODUCT_ID = 'zarfla_invite_1';
/** "Düğün Zinciri": 3 Davetiye Hakkı (tüketilebilir). Haklar sunucudaki credits/{uid} defterine yazılır. */
const BUNDLE_PRODUCT_ID = 'zarfla_invite_3';
/** Ürün → verdiği hak sayısı. zarfla_invite_1 eski doğrudan akışta kalır (deftere uğramaz). */
const PRODUCT_RIGHTS = Object.freeze({ [PRODUCT_ID]: 1, [BUNDLE_PRODUCT_ID]: 3 });
/** credits/{uid}.ledger en çok bu kadar kayıt tutar (eskiler düşer; bakiye lots'tan hesaplanır). */
const LEDGER_MAX = 200;

const H = 3600 * 1000;
const D = 24 * H;
const PAID_LIFE_MS = 365 * D;
const TTL_GRACE_MS = 30 * D;
/** İade/geri ödeme (voided) sonrası davetiye en geç bu kadar sonra kapanır (davetlilere süre tanır). */
const VOIDED_GRACE_MS = 24 * H;
/** Ücretsiz sınır denetiminde saat farkı toleransı (istemci saati ile sunucu saati). */
const FREE_LIMIT_SKEW_MS = 15 * 60 * 1000;
const MAX_DATA_CHARS = 200000;
const MAX_NAME = 120;

/** Hata: code = HttpsError kodu, reason = istemcinin ARB anahtarına çevirdiği kısa neden. */
class RedeemError extends Error {
  constructor(code, reason) {
    super(reason);
    this.code = code;
    this.reason = reason;
  }
}

function sha256(s) {
  return crypto.createHash('sha256').update(String(s), 'utf8').digest('hex');
}

const ID_RE = /^[A-Za-z0-9]{12}$/;
const TOKEN_RE = /^[a-z0-9]{1,24}$/;
const ISO_RE = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
// Kurallardaki safeName ile aynı: çift tırnak, ters bölü ve kontrol karakteri yok.
const NAME_FORBIDDEN = /["\\\x00-\x1f]/g;

function isValidInviteId(id) {
  return typeof id === 'string' && ID_RE.test(id);
}

function safeName(s) {
  const v = (typeof s === 'string' ? s : '').replace(NAME_FORBIDDEN, '');
  return v.length > MAX_NAME ? v.slice(0, MAX_NAME) : v;
}

/** redeemPurchase girdisini denetler. Dönen değer: normalize edilmiş girdi. */
function parseRedeemInput(raw) {
  const r = raw && typeof raw === 'object' ? raw : {};
  const purchaseToken = r.purchaseToken;
  const productId = r.productId;
  if (typeof purchaseToken !== 'string' || purchaseToken.length < 10 || purchaseToken.length > 4096) {
    throw new RedeemError('invalid-argument', 'bad-token');
  }
  if (!Object.prototype.hasOwnProperty.call(PRODUCT_RIGHTS, productId)) throw new RedeemError('invalid-argument', 'bad-product');
  const inviteId = r.inviteId == null || r.inviteId === '' ? null : r.inviteId;
  if (inviteId !== null && !isValidInviteId(inviteId)) throw new RedeemError('invalid-argument', 'bad-invite-id');
  const data = r.data == null ? null : r.data;
  if (inviteId !== null && typeof data !== 'string') throw new RedeemError('invalid-argument', 'bad-data');
  return { purchaseToken, productId, inviteId, data };
}

function rightsFor(productId) {
  return Object.prototype.hasOwnProperty.call(PRODUCT_RIGHTS, productId) ? PRODUCT_RIGHTS[productId] : 0;
}

function isBundle(productId) {
  return rightsFor(productId) > 1;
}

/** useCredit girdisi: { inviteId, data } ikisi de zorunlu. */
function parseUseCreditInput(raw) {
  const r = raw && typeof raw === 'object' ? raw : {};
  if (!isValidInviteId(r.inviteId)) throw new RedeemError('invalid-argument', 'bad-invite-id');
  if (typeof r.data !== 'string') throw new RedeemError('invalid-argument', 'bad-data');
  return { inviteId: r.inviteId, data: r.data };
}

// ---------------------------------------------------------------------------
// Hak defteri (credits/{uid}) — saf işlevler. Belge biçimi:
//   { balance, lots: [{ h, productId, rights, left, at, invites: [inviteId], voided }], ledger: [{ t, n, h, inviteId?, at }] }
//   h = sha256(satın alma jetonu) = purchases/{h}. balance her zaman iade edilmemiş lot'ların left toplamıdır.
//   Zaman damgaları ms (dizi içinde serverTimestamp kullanılamaz).
// ---------------------------------------------------------------------------

function normCredits(c) {
  const src = c && typeof c === 'object' ? c : {};
  const lots = Array.isArray(src.lots)
    ? src.lots.map((l) => ({
        h: String(l.h),
        productId: l.productId || null,
        rights: Number(l.rights) || 0,
        left: Math.max(0, Number(l.left) || 0),
        at: Number(l.at) || 0,
        invites: Array.isArray(l.invites) ? l.invites.slice() : [],
        voided: l.voided === true,
      }))
    : [];
  const ledger = Array.isArray(src.ledger) ? src.ledger.slice() : [];
  return { balance: balanceOf(lots), lots, ledger };
}

function balanceOf(lots) {
  return lots.reduce((s, l) => s + (l.voided ? 0 : l.left), 0);
}

function pushLedger(ledger, e) {
  const out = [...ledger, e];
  return out.length > LEDGER_MAX ? out.slice(out.length - LEDGER_MAX) : out;
}

/** Bu davetiye daha önce bir haktan ödendiyse o lot'un h'si (idempotentlik). */
function lotForInvite(credits, inviteId) {
  const c = normCredits(credits);
  const lot = c.lots.find((l) => l.invites.includes(inviteId));
  return lot ? lot.h : null;
}

/** Paket alımını deftere ekler (aynı h ikinci kez eklenmez). */
function applyGrant(credits, { h, productId, rights, nowMs }) {
  const c = normCredits(credits);
  if (c.lots.some((l) => l.h === h)) return c;
  const lots = [...c.lots, { h, productId, rights, left: rights, at: nowMs, invites: [], voided: false }];
  return { balance: balanceOf(lots), lots, ledger: pushLedger(c.ledger, { t: 'grant', n: rights, h, at: nowMs }) };
}

/**
 * Bir hak kullanır. [preferH] verilirse önce o lot (yeni alınan paket), yoksa en eski dolu lot (FIFO).
 * Bakiye yoksa RedeemError('failed-precondition', 'no-credit').
 */
function applyUse(credits, { inviteId, nowMs, preferH = null }) {
  const c = normCredits(credits);
  const usable = (l) => !l.voided && l.left > 0;
  let idx = preferH ? c.lots.findIndex((l) => l.h === preferH && usable(l)) : -1;
  if (idx < 0) idx = c.lots.findIndex(usable);
  if (idx < 0) throw new RedeemError('failed-precondition', 'no-credit');
  const lots = c.lots.map((l, i) => (i === idx ? { ...l, left: l.left - 1, invites: [...l.invites, inviteId] } : l));
  const h = lots[idx].h;
  return {
    credits: { balance: balanceOf(lots), lots, ledger: pushLedger(c.ledger, { t: 'use', n: -1, h, inviteId, at: nowMs }) },
    h,
  };
}

/**
 * İade (voided) politikası: paketin KALAN hakları silinir (balance düşer), lot iade edildi işaretlenir.
 * Paketle yayınlanmış davetiyeler ayrıca kapatılır (services.processVoided). Dönen değer: { credits, removed, invites }.
 */
function applyVoid(credits, h, nowMs) {
  const c = normCredits(credits);
  const idx = c.lots.findIndex((l) => l.h === h);
  if (idx < 0) return { credits: c, removed: 0, invites: [] };
  const lot = c.lots[idx];
  if (lot.voided) return { credits: c, removed: 0, invites: lot.invites.slice() };
  const removed = lot.left;
  const lots = c.lots.map((l, i) => (i === idx ? { ...l, left: 0, voided: true } : l));
  return {
    credits: { balance: balanceOf(lots), lots, ledger: pushLedger(c.ledger, { t: 'void', n: -removed, h, at: nowMs }) },
    removed,
    invites: lot.invites.slice(),
  };
}

/**
 * Google Play ProductPurchase (purchases.products.get) denetimi.
 * Dönen değer: null (hak verilebilir) ya da neden.
 * purchaseState: 0 satın alındı, 1 iptal, 2 beklemede · consumptionState: 0 tüketilmedi, 1 tüketildi.
 */
function checkProductPurchase(p, productId = PRODUCT_ID) {
  if (!p || typeof p !== 'object') return 'not-purchased';
  if (p.productId && p.productId !== productId) return 'bad-product';
  if (p.purchaseState === 2) return 'pending';
  if (p.purchaseState !== 0) return 'not-purchased';
  if (p.consumptionState === 1) return 'consumed';
  return null;
}

/** Kurallardaki dataOk'un birebir JS karşılığı (sunucu yazdığı belgeyi istemci güncelleyebilsin diye). */
function ruleDataOk(json, f, id) {
  if (typeof json !== 'string' || json.length >= MAX_DATA_CHARS) return false;
  const start = new RegExp('^\\{"id":"' + id + '","type":"' + f.type + '","theme":"' + f.theme + '",[\\s\\S]*\\}$');
  if (!start.test(json)) return false;
  for (const k of ['id', 'type', 'theme', 'plan', 'status', 'n1', 'n2', 'date']) {
    if (new RegExp('"' + k + '"\\s*:[\\s\\S]*"' + k + '"\\s*:').test(json)) return false;
  }
  if (/\\u00[2-7][0-9a-fA-F]/.test(json)) return false;
  if (!json.includes('"n1":"' + f.n1 + '"')) return false;
  if (!json.includes('"n2":"' + f.n2 + '"')) return false;
  if (!json.includes('"date":"' + f.date + '"')) return false;
  if (!json.includes('"status":"live"')) return false;
  if (!json.includes('"plan":"' + (f.plan === 'paid' ? 'premium' : 'free') + '"')) return false;
  // Hediye IBAN'ı yalnız ücretli planda (kurallardaki dataOk ile aynı).
  if (f.plan !== 'paid' && /"iban"\s*:/.test(json)) return false;
  // Arka plan müziği yalnız ücretli planda; değer seçki kimliği biçiminde (kurallardaki dataOk ile aynı).
  if (/"music"\s*:[\s\S]*"music"\s*:/.test(json)) return false;
  if (/"music"\s*:/.test(json) && (f.plan !== 'paid' || !/"music":"[a-z0-9-]{1,40}"[,}]/.test(json))) return false;
  return true;
}

/**
 * İstemcinin gönderdiği davetli sayfası JSON'undan ücretli belge alanlarını üretir.
 * Anahtar sırası sözleşmedir: {"id","type","theme", ...}. plan "premium", status "live" zorlanır.
 * Dönen değer: { data, lock } — lock: type, theme, n1, n2, date, origDate, nameEdits, dateEdits.
 */
function buildPaidData(dataStr, inviteId) {
  if (typeof dataStr !== 'string' || dataStr.length >= MAX_DATA_CHARS) throw new RedeemError('invalid-argument', 'bad-data');
  let obj;
  try {
    obj = JSON.parse(dataStr);
  } catch (_) {
    throw new RedeemError('invalid-argument', 'bad-data');
  }
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) throw new RedeemError('invalid-argument', 'bad-data');
  const type = obj.type;
  const theme = obj.theme;
  const date = obj.date;
  if (typeof type !== 'string' || !TOKEN_RE.test(type)) throw new RedeemError('invalid-argument', 'bad-type');
  if (typeof theme !== 'string' || !TOKEN_RE.test(theme)) throw new RedeemError('invalid-argument', 'bad-theme');
  if (typeof date !== 'string' || !ISO_RE.test(date)) throw new RedeemError('invalid-argument', 'bad-date');
  const n1 = safeName(obj.n1);
  const n2 = safeName(obj.n2);
  const out = { id: inviteId, type, theme };
  for (const k of Object.keys(obj)) {
    if (k === 'id' || k === 'type' || k === 'theme') continue;
    out[k] = obj[k];
  }
  out.n1 = n1;
  out.n2 = n2;
  out.date = date;
  out.status = 'live';
  out.plan = 'premium';
  const data = JSON.stringify(out);
  const lock = { type, theme, n1, n2, date, origDate: date, nameEdits: 0, dateEdits: 0 };
  if (!ruleDataOk(data, { ...lock, plan: 'paid' }, inviteId)) throw new RedeemError('invalid-argument', 'bad-data');
  return { data, lock };
}

function paidTimes(nowMs) {
  const expiresAtMs = nowMs + PAID_LIFE_MS;
  return { expiresAtMs, deleteAtMs: expiresAtMs + TTL_GRACE_MS };
}

/** İade edilen ücretli davetiyenin yeni süresi: mevcut ile şimdi+24 saatin küçüğü. */
function voidedTimes(currentExpMs, nowMs) {
  const expiresAtMs = Math.min(currentExpMs, nowMs + VOIDED_GRACE_MS);
  return { expiresAtMs, deleteAtMs: expiresAtMs + TTL_GRACE_MS };
}

function toMs(v) {
  if (v == null) return null;
  if (typeof v === 'number') return v;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return null;
}

/**
 * Ücretsiz sınır: aynı sahibin, bu belgeden ÖNCE oluşturulmuş ve hâlâ açık (tolerans payıyla)
 * başka ücretsiz davetiyesi varsa yeni belge kapatılmalı.
 * others: [{ id, plan, expiresAt, createdAt }]
 */
function shouldRevokeFree(newDoc, others, nowMs) {
  if (!newDoc || newDoc.plan !== 'free') return false;
  const newCreated = toMs(newDoc.createdAt) ?? nowMs;
  return others.some((o) => {
    if (o.id === newDoc.id || o.plan !== 'free') return false;
    const exp = toMs(o.expiresAt);
    const created = toMs(o.createdAt);
    if (exp == null || exp <= nowMs + FREE_LIMIT_SKEW_MS) return false;
    return created == null || created < newCreated;
  });
}

/** Storage nesne adlarını davetiye kimliğine göre gruplar: invites/{id}/{dosya}. */
function groupFilesByInvite(names) {
  const m = new Map();
  for (const n of names) {
    const parts = String(n).split('/');
    if (parts.length < 3 || parts[0] !== 'invites' || !isValidInviteId(parts[1])) continue;
    if (!m.has(parts[1])) m.set(parts[1], []);
    m.get(parts[1]).push(n);
  }
  return m;
}

/** Belge yoksa (TTL ile silinmiş) ya da deleteAt geçtiyse dosyalar silinir. */
function isStaleInvite(exists, data, nowMs) {
  if (!exists) return true;
  const del = toMs(data && data.deleteAt);
  return del != null && del < nowMs;
}

module.exports = {
  PACKAGE_NAME,
  PRODUCT_ID,
  BUNDLE_PRODUCT_ID,
  PRODUCT_RIGHTS,
  LEDGER_MAX,
  rightsFor,
  isBundle,
  parseUseCreditInput,
  normCredits,
  lotForInvite,
  applyGrant,
  applyUse,
  applyVoid,
  PAID_LIFE_MS,
  TTL_GRACE_MS,
  VOIDED_GRACE_MS,
  FREE_LIMIT_SKEW_MS,
  RedeemError,
  sha256,
  isValidInviteId,
  safeName,
  parseRedeemInput,
  checkProductPurchase,
  ruleDataOk,
  buildPaidData,
  paidTimes,
  voidedTimes,
  toMs,
  shouldRevokeFree,
  groupFilesByInvite,
  isStaleInvite,
};
