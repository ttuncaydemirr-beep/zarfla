/// Google Play Faturalandırma ↔ redeemPurchase sözleşmesi — saf Dart (eklentiye bağımlı değil, test edilebilir).
///
/// Ürün: tek seferlik, TÜKETİLEBİLİR "1 Davetiye Hakkı" (abonelik yok). Akış:
///   satın al → jeton → redeemPurchase (sunucu Google Play'de doğrular, davetiyeyi ücretli yazar)
///   → başarıda uygulama alımı TÜKETİR (tüketme yalnız sunucu hakkı verdikten sonra).
/// Tüketilmemiş alım = kullanılmamış hak: uygulama açılışında ya da bir sonraki ücretli yayında kullanılır.
library;

const String kInviteProductId = 'zarfla_invite_1';

/// Cloud Functions bölgesi (functions/index.js ile aynı).
const String kFunctionsRegion = 'europe-west3';
const String kRedeemFunction = 'redeemPurchase';

/// Sunucu reddettiğinde alımla ne yapılacağı.
enum RedeemAction {
  /// Hak başka bir davetiyede kullanılmış: tüket (yeniden satın alma engellenmesin).
  consume,

  /// Alım korunur (geçici hata ya da kullanılmamış hak): sonra tekrar denenir.
  keep,

  /// Alım geçersiz (iptal/iade/geçersiz jeton): bir şey yapılmaz.
  drop,
}

/// redeemPurchase başarısızlığı: [key] ARB metin anahtarı.
class RedeemFailure implements Exception {
  const RedeemFailure(this.key, this.action);

  final String key;
  final RedeemAction action;

  @override
  String toString() => 'RedeemFailure($key, $action)';
}

/// Sunucu hatası (HttpsError kodu + neden) → kullanıcı metni ve alım eylemi.
/// Nedenler: functions/src/logic.js ve services.js'teki RedeemError reason değerleri.
RedeemFailure redeemFailureFor(String code, String? reason) {
  switch ((reason ?? '').trim()) {
    case 'token-used':
      return const RedeemFailure('payUsed', RedeemAction.consume);
    case 'needs-invite':
      return const RedeemFailure('payCredit', RedeemAction.keep);
    case 'pending':
      return const RedeemFailure('payPending', RedeemAction.keep);
    case 'voided':
      return const RedeemFailure('payRefunded', RedeemAction.drop);
    case 'not-purchased':
    case 'consumed':
    case 'invalid-token':
    case 'bad-product':
    case 'bad-token':
      return const RedeemFailure('payErr', RedeemAction.drop);
    case 'bad-data':
    case 'bad-type':
    case 'bad-theme':
    case 'bad-date':
    case 'bad-invite-id':
      return const RedeemFailure('payDataErr', RedeemAction.keep);
    case 'not-owner':
    case 'already-paid':
      return const RedeemFailure('payErr', RedeemAction.keep);
  }
  final c = code.toLowerCase().replaceAll('_', '-');
  if (c == 'unauthenticated' || c == 'permission-denied') {
    return const RedeemFailure('cloudDenied', RedeemAction.keep);
  }
  // unavailable, internal, deadline-exceeded, not-found (fonksiyon yok), ağ hatası…: hak korunur, sonra yeniden denenir.
  return const RedeemFailure('payVerifyErr', RedeemAction.keep);
}

/// Satın alma başlamadan kaydedilen bağlam: hangi taslak, hangi bulut kimliğiyle yayınlanacak.
/// Uygulama kapanıp açılsa da (bekleyen ödeme, çökme) aynı bulut kimliği kullanılır → sunucu idempotent.
class PendingPaid {
  const PendingPaid({required this.invId, required this.cloudId});

  final String invId;
  final String cloudId;

  Map<String, dynamic> toJson() => {'inv': invId, 'cid': cloudId};

  static PendingPaid? fromJson(Object? j) {
    if (j is! Map) return null;
    final inv = j['inv'], cid = j['cid'];
    if (inv is! String || cid is! String || inv.isEmpty || !RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(cid)) return null;
    return PendingPaid(invId: inv, cloudId: cid);
  }
}
