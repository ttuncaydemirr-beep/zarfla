/// Google Play Faturalandırma ↔ redeemPurchase sözleşmesi — saf Dart (eklentiye bağımlı değil, test edilebilir).
///
/// Ürün: tek seferlik, TÜKETİLEBİLİR "1 Davetiye Hakkı" (abonelik yok). Akış:
///   satın al → jeton → redeemPurchase (sunucu Google Play'de doğrular, davetiyeyi ücretli yazar)
///   → başarıda uygulama alımı TÜKETİR (tüketme yalnız sunucu hakkı verdikten sonra).
/// Tüketilmemiş alım = kullanılmamış hak: uygulama açılışında ya da bir sonraki ücretli yayında kullanılır.
library;

const String kInviteProductId = 'zarfla_invite_1';

/// "Düğün Zinciri": 3 Davetiye Hakkı (tüketilebilir). Sunucu 3 hakkı credits/{uid} defterine yazar;
/// her ücretli yayın 1 hak kullanır (useCredit). Herhangi 3 davetiye için (kına + nişan + düğün gibi).
const String kBundleProductId = 'zarfla_invite_3';

/// Uygulamanın sattığı tüm ürünler.
const Set<String> kProductIds = {kInviteProductId, kBundleProductId};

/// Ürünün verdiği hak sayısı (functions/src/logic.js PRODUCT_RIGHTS ile aynı). Bilinmeyen ürün: 0.
int rightsFor(String productId) => switch (productId) {
      kInviteProductId => 1,
      kBundleProductId => 3,
      _ => 0,
    };

bool isBundleProduct(String productId) => rightsFor(productId) > 1;

/// Cloud Functions bölgesi (functions/index.js ile aynı).
const String kFunctionsRegion = 'europe-west3';
const String kRedeemFunction = 'redeemPurchase';
const String kUseCreditFunction = 'useCredit';

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
    case 'no-credit':
      // Sunucuda bakiye kalmamış (başka cihazda kullanıldı / iade): yeni satın almaya geçilir.
      return const RedeemFailure('creditNone', RedeemAction.keep);
    case 'pending':
      return const RedeemFailure('payPending', RedeemAction.keep);
    case 'voided':
      return const RedeemFailure('payRefunded', RedeemAction.drop);
    case 'bad-product':
      // Sunucu ürünü tanımıyor (ör. paket ürünü sunucu yayınından önce satıldı): alım korunur,
      // sunucu güncellenince açılışta / "Satın alımı geri yükle" ile tamamlanır.
      return const RedeemFailure('payVerifyErr', RedeemAction.keep);
    case 'not-purchased':
    case 'consumed':
    case 'invalid-token':
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

// ---- Satın alımı geri yükle + "Ödemeniz doğrulanıyor…" bandı ----

/// Sunucu doğrulaması henüz yapılamamış (alım korunuyor, yeniden denenecek) sonuçlar.
/// Bu durumlarda ana ekranda "Ödemeniz doğrulanıyor…" bandı gösterilir.
const Set<String> kUnverifiedResults = {'payVerifyErr', 'payPending', 'payProcessing', 'cloudDenied', 'cloudSetup'};

/// Tek bir alım işleme sonucu (null = hak verildi) doğrulama bekliyor mu?
bool isUnverifiedResult(String? key) => key != null && kUnverifiedResults.contains(key);

/// Geri yükleme sonrası bant gösterilsin mi: Play'de bekleyen alım varsa ya da en az bir alım doğrulanamadıysa.
bool needsVerifyBanner(Iterable<String?> results, {int pending = 0}) =>
    pending > 0 || results.any(isUnverifiedResult);

/// "Satın alımı geri yükle" sonucu → kullanıcı metni (ARB anahtarı).
/// [results]: sahip olunan her tüketilmemiş alım için işleme sonucu (null = hak verildi/tamamlandı).
/// [pending]: Play'de henüz onaylanmamış (beklemede) alım sayısı. [queryFailed]: Play sorgusu başarısız.
/// Öncelik: tamamlandı > kullanılmamış hak > beklemede > hata > geri yüklenecek bir şey yok.
String restoreMessageKey(List<String?> results, {int pending = 0, bool queryFailed = false}) {
  if (results.any((r) => r == null || r == 'paidPhotoErr')) return 'restoreDone';
  if (results.contains('payCredit')) return 'restoreCredit';
  if (pending > 0 || results.any((r) => r == 'payPending' || r == 'payProcessing')) return 'restorePending';
  if (queryFailed) return 'restoreErr';
  // Hak başka davetiyede kullanılmış (tüketildi) ya da alım iade/geçersiz: geri yüklenecek bir şey kalmadı.
  const settled = {'payUsed', 'payRefunded'};
  if (results.any((r) => !settled.contains(r))) return 'restoreErr';
  return 'restoreNone';
}

// ---- "Düğün Zinciri" paketi: hak bakiyesi, yayın yolu, tasarruf rozeti ----

/// Sunucu yanıtındaki (redeemPurchase / useCredit) güncel bakiye; yoksa null.
int? creditsFromResponse(Map<String, dynamic> res) {
  final c = res['credits'];
  return c is num && c >= 0 ? c.toInt() : null;
}

/// credits/{uid} belgesinden bakiye (yoksa / bozuksa 0).
int balanceFromDoc(Map<String, dynamic>? d) {
  final b = d?['balance'];
  return b is num && b > 0 ? b.toInt() : 0;
}

/// Ücretli yayında izlenecek yol.
enum PaidRoute {
  /// Sunucudaki paket hakkı kullanılır (useCredit) — yeni satın alma yok.
  serverCredit,

  /// Cihazda tüketilmemiş (sunucunun henüz işlemediği) alım var: önce o işlenir.
  unconsumed,

  /// Google Play satın alma penceresi açılır.
  buy,
}

/// Öncelik: tüketilmemiş alım (Play yeni alımı engeller, para alınmış) > sunucu bakiyesi > satın alma.
PaidRoute paidRouteFor({required int balance, required bool hasUnconsumed}) {
  if (hasUnconsumed) return PaidRoute.unconsumed;
  if (balance > 0) return PaidRoute.serverCredit;
  return PaidRoute.buy;
}

/// Paketin tekli alıma göre tasarruf yüzdesi — Play'in yerelleştirilmiş fiyatlarından (sabit yazılmaz).
/// Ör. 3 × 399 TL = 1197 TL yerine 899 TL → 25. Aynı para birimi değilse, fiyat yoksa ya da tasarruf
/// %1'in altındaysa null (rozet gösterilmez).
int? bundleSavingsPercent({
  required double? single,
  required double? bundle,
  String? singleCurrency,
  String? bundleCurrency,
  int rights = 3,
}) {
  if (single == null || bundle == null || single <= 0 || bundle <= 0 || rights < 2) return null;
  if (singleCurrency != null && bundleCurrency != null && singleCurrency != bundleCurrency) return null;
  final full = single * rights;
  final pct = ((full - bundle) / full * 100).round();
  return pct >= 1 && pct < 100 ? pct : null;
}

/// "N hakkınız kaldı" metin anahtarı (Arapça ikil biçimi için 2 ayrı).
String creditsLeftKey(int n) => n == 1 ? 'creditsLeft1' : (n == 2 ? 'creditsLeft2' : 'creditsLeftN');
