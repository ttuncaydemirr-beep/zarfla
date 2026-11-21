'use strict';

// App Check: İZLEME kipi (varsayılan) ya da ZORLAMA kipi. Saf ve test edilebilir; firebase-functions'a bağımlı değil.
// Zorlamayı açmak için index.js içindeki ENFORCE_APP_CHECK=true yapılır VE istemci metrikleri (Firebase konsolu →
// App Check → API'ler → Cloud Functions → doğrulanmış istek oranı) iyiyse işlevler yeniden yayınlanır.

/** onCall seçeneklerine enforceAppCheck ekler. false iken alan hiç eklenmez (mevcut davranış birebir korunur). */
function callOptions(enforce, base) {
  return enforce ? { ...base, enforceAppCheck: true } : { ...base };
}

/**
 * İzleme: istekte doğrulanmış App Check jetonu var mı? Yalnız işlev adı + bool günlüğe yazılır (uid/IP/jeton YOK).
 * Günlük tabanlı metrik: jsonPayload.message="appcheck" sayımı, verified=true/false kırılımı.
 * Zorlama açıkken (enforce) platform zaten jetonsuz isteği reddeder; günlük yine yazılır (tutarlı metrik).
 * Hiçbir koşulda atmaz: izleme, işlevi asla bozmamalı.
 */
function monitorAppCheck(req, fn, log) {
  let verified = false;
  try {
    verified = !!(req && req.app);
    log.info('appcheck', { fn, verified });
  } catch (_) {
    /* sessiz */
  }
  return verified;
}

module.exports = { callOptions, monitorAppCheck };
