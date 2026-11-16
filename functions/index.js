'use strict';

// Zarfla — Cloud Functions (2. nesil, Node 22). Bölge: europe-west3 (Firestore/Storage ile aynı).
// Çalışma kimliği: ayrı hizmet hesabı (SERVICE_ACCOUNT). Anahtar dosyası YOK; Google Play Developer API'ye
// bu hesabın varsayılan kimlik bilgileriyle erişilir (Play Console'da bu e-postaya izin verilmeli).
// Kurulum: /home/claude/staging/stage3/billing_setup.md (sahibinin adımları) · README "Aşama 3".

const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { google } = require('googleapis');

const L = require('./src/logic');
const S = require('./src/services');

const REGION = 'europe-west3';
const PROJECT_ID = 'zarfla-37da9';
const BUCKET = 'zarfla-37da9.firebasestorage.app';
const SERVICE_ACCOUNT = `zarfla-functions@${PROJECT_ID}.iam.gserviceaccount.com`;

setGlobalOptions({ region: REGION, serviceAccount: SERVICE_ACCOUNT, maxInstances: 5, memory: '256MiB' });

initializeApp();

let _publisher;
function publisher() {
  if (_publisher) return _publisher;
  const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
  const ap = google.androidpublisher({ version: 'v3', auth });
  const packageName = L.PACKAGE_NAME;
  _publisher = {
    async getProduct(productId, token) {
      const r = await ap.purchases.products.get({ packageName, productId, token });
      return r.data;
    },
    async acknowledge(productId, token) {
      await ap.purchases.products.acknowledge({ packageName, productId, token, requestBody: {} });
    },
    async listVoided({ startTimeMs, pageToken }) {
      const r = await ap.purchases.voidedpurchases.list({
        packageName,
        startTime: String(startTimeMs),
        type: 0, // yalnız uygulama içi ürünler
        maxResults: 1000,
        token: pageToken,
      });
      return r.data;
    },
  };
  return _publisher;
}

function deps() {
  return {
    db: getFirestore(),
    fv: { serverTimestamp: () => FieldValue.serverTimestamp(), ts: (ms) => Timestamp.fromMillis(ms) },
    publisher: publisher(),
    bucket: getStorage().bucket(BUCKET),
    now: () => Date.now(),
    log: { info: logger.info, warn: logger.warn, error: logger.error },
  };
}

/** Uygulama: satın alma → redeemPurchase → başarıda tüketme. Girdi: { inviteId, purchaseToken, productId, data }.
 *  productId zarfla_invite_1 (tek davetiye, doğrudan) ya da zarfla_invite_3 (3 hak → credits/{uid}; inviteId varsa 1'i hemen kullanılır). */
exports.redeemPurchase = onCall({ timeoutSeconds: 60 }, async (req) => {
  const uid = req.auth && req.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'no-auth');
  try {
    return await S.redeem(deps(), uid, req.data);
  } catch (e) {
    if (e instanceof L.RedeemError) throw new HttpsError(e.code, e.reason);
    logger.error('redeemPurchase failed', e);
    throw new HttpsError('unavailable', 'server-error');
  }
});

/** Paket hakkı kullan: { inviteId, data } → credits/{uid}'den 1 hak düşer, davetiye ücretli yazılır (Play'e gidilmez). */
exports.useCredit = onCall({ timeoutSeconds: 30 }, async (req) => {
  const uid = req.auth && req.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'no-auth');
  try {
    return await S.useCredit(deps(), uid, req.data);
  } catch (e) {
    if (e instanceof L.RedeemError) throw new HttpsError(e.code, e.reason);
    logger.error('useCredit failed', e);
    throw new HttpsError('unavailable', 'server-error');
  }
});

/** Günlük: Google Play iade/geri ödeme kayıtları → davetiye 24 saat içinde kapanır, premium yeniden hesaplanır. */
exports.voidedPurchases = onSchedule({ schedule: '23 4 * * *', timeZone: 'Europe/Istanbul', timeoutSeconds: 300 }, async () => {
  await S.processVoided(deps());
});

/** Yeni ücretsiz davetiye: aynı sahibin açık başka ücretsizi varsa yenisi kapatılır (kural sayamaz). */
exports.enforceFreeLimit = onDocumentCreated({ document: 'invites/{id}' }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  await S.enforceFreeLimit(deps(), event.params.id, snap.data());
});

/** Günlük: TTL ile silinmiş ya da deleteAt'i geçmiş davetiyelerin Storage dosyalarını siler. */
exports.cleanupStorage = onSchedule({ schedule: '41 4 * * *', timeZone: 'Europe/Istanbul', timeoutSeconds: 540 }, async () => {
  await S.cleanupStorage(deps());
});
