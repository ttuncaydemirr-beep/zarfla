import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../billing/billing_logic.dart';
import '../billing/billing_service.dart';
import '../cloud/cloud_service.dart';
import '../cloud/invite_contract.dart';
import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/lock_rules.dart';
import '../logic/sample_names.dart';
import '../models/invitation.dart';
import '../notify/reminder_service.dart';
import '../startup/startup_log.dart';
import '../storage/invitation_store.dart';
import '../storage/photo_store.dart';

/// Ilk açılışta cihaz diline göre arayüz dili: yalnız yeni diller (es/pt/id) otomatik seçilir; yoksa null.
String? firstRunLang(String? deviceLang) {
  final c = (deviceLang ?? '').toLowerCase();
  const auto = ['es', 'pt', 'id'];
  return auto.contains(c) ? c : null;
}

/// Uygulama durumu: tek ChangeNotifier + provider.
/// Neden provider: tek ekranlı akış ve az sayıda paylaşılan durum için en sade,
/// en yaygın ve kod üretimi gerektirmeyen seçenek (riverpod'a gerek yok).
class AppState extends ChangeNotifier {
  AppState({required this.strings, required InvitationStore store, required PhotoStore photos, this.cloud, this.billing})
      : _store = store,
        _photos = photos;

  final AppStrings strings;

  /// Firebase katmanı (testlerde ve Firebase başlatılamazsa null olabilir).
  final CloudService? cloud;

  /// Google Play Faturalandırma (testlerde ve Android dışında null olabilir).
  final BillingService? billing;
  final InvitationStore _store;
  final PhotoStore _photos;

  String lang = 'tr';
  bool premiumUser = false;
  final List<Invitation> invitations = [];

  /// Son kaydetme başarısız olduysa true (cihazda yer yok).
  bool lastSaveFailed = false;

  /// Her başarılı/başarısız kaydetmede artar: editördeki "Kaydedildi ✓" göstergesi dinler.
  final ValueNotifier<int> savedTick = ValueNotifier<int>(0);

  /// Silinmek üzere gizlenen davetiyeler ("Geri al" süresi dolana kadar listede görünmez, cihazda durur).
  final Set<String> _hidden = {};

  /// Açılış yüklemesi. Her adım ayrı korunur: biri başarısız olursa (eski sürümün verisi, eklenti hatası)
  /// kaydedilir ve diğerleri yine çalışır; bu işlev hiçbir koşulda istisna fırlatmaz.
  ///
  /// [deviceLang]: cihazın dil kodu (ör. "es"). YALNIZ kayıtlı bir dil seçimi yoksa (ilk açılış) ve cihaz dili
  /// desteklenen yeni dillerden (es/pt/id) biriyse o dil seçilir; diğer cihazlarda varsayılan Türkçe kalır.
  Future<void> init({String? deviceLang}) async {
    Future<void> step(String name, Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e, st) {
        StartupLog.record('init.$name', e, st);
      }
    }

    await step('photos', _photos.init);
    await step('lang', () async {
      final l = await _store.loadLang();
      if (l != null && kLangs.contains(l)) {
        lang = l;
      } else if (l == null) {
        lang = firstRunLang(deviceLang) ?? lang;
      }
    });
    await step('premium', () async => premiumUser = await _store.loadPremiumUser());
    await step('invitations', () async {
      final loaded = await _store.loadAll();
      invitations
        ..clear()
        ..addAll(loaded);
    });
    var migrated = false;
    // Aşama 1'de "yayınlanan" davetiyeler yalnız cihazdaydı (bağlantı çalışmıyordu, ödeme sahteydi):
    // bulut kimliği olmayan yayındakiler taslağa döner, hakları sıfırlanır.
    await step('migrateStage1', () async {
      for (final i in invitations) {
        if (i.isLive && i.cloudId == null) {
          i
            ..status = 'draft'
            ..plan = null
            ..nameEditsLeft = kNameEdits
            ..dateEditsLeft = kDateEdits
            ..originalDate = null
            ..expiresAt = null
            ..cloudFiles = {};
          migrated = true;
        }
      }
    });
    // Tek seferlik: eski sürümün otomatik doldurduğu örnek isimleri temizle.
    await step('migrateSampleNames', () async {
      const flag = 'zarfla_sample_names_cleared_v1';
      if (!await _store.loadFlag(flag)) {
        for (final i in invitations) {
          try {
            if (clearSampleNames(i)) migrated = true;
          } catch (e, st) {
            StartupLog.record('init.sampleNames', e, st);
          }
        }
        await _store.saveFlag(flag, true);
      }
    });
    if (migrated) await step('save', () async => _store.saveAll(invitations));
  }

  /// Açılışta anonim oturumu arka planda hazırla (başarısızlık sessiz; yayınlarken yeniden denenir).
  /// Sunucudaki premium (reklamsız) bayrağı da okunur (yalnız açar, kapatmaz).
  Future<void> warmUpCloud() async {
    final c = cloud;
    if (c == null || !c.ready) return;
    try {
      await c.ensureUser();
      if (!premiumUser && await c.fetchPremium()) await _setPremiumUser();
      await refreshCredits();
    } catch (_) {}
  }

  /// Sunucudaki paket hakkı bakiyesini (credits/{uid}) okur. Anonim oturum: yalnız aynı uid'de görünür
  /// (uygulama silinip kurulursa yeni uid → bakiye görünmez; bkz. README / billing_logic).
  Future<void> refreshCredits() async {
    final c = cloud;
    if (c == null || !c.ready) return;
    final n = await c.fetchCredits();
    if (n != null) _setCredits(n);
  }

  void _setCredits(int n) {
    if (creditBalance == n) return;
    creditBalance = n;
    notifyListeners();
  }

  Future<void> _setPremiumUser() async {
    if (premiumUser) return;
    premiumUser = true;
    notifyListeners();
    await _store.savePremiumUser(true);
  }

  String t(String key, [Map<String, Object> args = const {}]) => strings.get(lang, key, args);

  Future<void> setLang(String l) async {
    if (!kLangs.contains(l)) return;
    lang = l;
    notifyListeners();
    await _store.saveLang(l);
    Reminders.instance.sync(); // bildirim metinleri yeni dilde yeniden zamanlanır
  }

  Invitation? byId(String id) {
    for (final i in invitations) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<Invitation> get sorted =>
      invitations.where((i) => !_hidden.contains(i.id)).toList()..sort((a, b) => b.created.compareTo(a.created));

  bool isHidden(String id) => _hidden.contains(id);

  static final _rnd = Random.secure();
  String newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(6, (_) => chars[_rnd.nextInt(chars.length)]).join();
    return r + DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(4);
  }

  Invitation createDraft(String type) =>
      Invitation.create(id: newId(), type: type, lang: lang, now: DateTime.now().millisecondsSinceEpoch);

  Future<bool> add(Invitation inv) async {
    invitations.add(inv);
    return save();
  }

  /// Değişikliği kaydet ve ekranları yenile.
  Future<bool> save({bool notify = true}) async {
    if (notify) notifyListeners();
    final ok = await _store.saveAll(invitations);
    lastSaveFailed = !ok;
    savedTick.value++;
    Reminders.instance.sync(); // hatırlatmalar: yayın/ödeme/silme/düzenleme sonrası yeniden hesaplanır (başlamadıysa etkisiz)
    return ok;
  }

  /// Silme 1. adım (onaydan sonra): davetiye listeden gizlenir, hiçbir şey silinmez. Uygulama bu arada
  /// kapanırsa davetiye geri gelir (güvenli taraf). [undoDelete] geri alır, [commitDelete] gerçekten siler.
  void hideForDelete(Invitation inv) {
    if (_hidden.add(inv.id)) notifyListeners();
  }

  void undoDelete(String id) {
    if (_hidden.remove(id)) notifyListeners();
  }

  /// Silme 2. adım ("Geri al" süresi doldu): buluttan ve cihazdan siler. Hata olursa davetiye yeniden görünür
  /// ve hata metin anahtarı döner.
  Future<String?> commitDelete(String id) async {
    if (!_hidden.contains(id)) return null;
    final inv = byId(id);
    String? err;
    if (inv != null) err = await deleteInvitation(inv);
    _hidden.remove(id);
    notifyListeners();
    return err;
  }

  /// Sil: yayındaysa önce buluttan (Storage + Firestore), sonra cihazdan.
  /// Dönen değer: null (başarılı) ya da hata metin anahtarı (bu durumda cihazdan da silinmez).
  Future<String?> deleteInvitation(Invitation inv) async {
    if (inv.cloudId != null) {
      final c = cloud;
      if (c == null || !c.ready) return 'delCloudErr';
      try {
        await c.delete(inv);
      } on CloudError catch (e) {
        return e.key == 'netErr' ? 'delCloudErr' : e.key;
      }
    }
    await delete(inv);
    return null;
  }

  Future<void> delete(Invitation inv) async {
    invitations.removeWhere((i) => i.id == inv.id);
    await save();
    await _photos.delete(inv.cover);
    for (final p in inv.photos) {
      await _photos.delete(p);
    }
  }

  bool isExpired(Invitation inv) => inv.isExpiredAt(DateTime.now());

  /// Ücretsiz yayın: Firestore belgesi + Storage fotoğrafları. Dönen değer: null ya da hata metin anahtarı.
  /// Ücretli yayın: [publishPaid].
  Future<String?> publishFree(Invitation inv) async {
    final c = cloud;
    if (c == null || !c.ready) return 'cloudSetup';
    if (kThemes[inv.theme]?.premium ?? false) return 'premThemeNeed';
    // Kötüye kullanım sınırı (istemci tarafı): aynı anda en fazla 1 aktif ücretsiz davetiye.
    if (activeFreeCount(invitations, DateTime.now(), exceptId: inv.id) >= kMaxActiveFree) return 'freeLimit';
    // Kural gereği: ilk yayında sayaçlar sıfır, isimlerde " \\ ve kontrol karakteri yok.
    inv
      ..n1 = cloudSafeName(inv.n1)
      ..n2 = cloudSafeName(inv.n2)
      ..nameEditsLeft = kNameEdits
      ..dateEditsLeft = kDateEdits;
    try {
      await c.publishFree(inv);
    } on CloudError catch (e) {
      return e.key;
    }
    await save();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Ücretli yayın: Google Play "1 Davetiye Hakkı" / "Düğün Zinciri" (3 hak, tüketilebilir) + redeemPurchase
  // ---------------------------------------------------------------------------

  /// Sunucudaki kullanılmamış paket hakkı ("2 hakkınız kaldı"). Yalnız sunucu yanıtı / credits belgesiyle değişir.
  int creditBalance = 0;
  bool _creditBusy = false;

  PendingPaid? _pending;
  Completer<String?>? _buyWait;
  final Set<String> _inFlight = {};

  /// Sunucunun henüz hak vermediği, tüketilmemiş alım (kullanılmamış hak).
  BillingPurchase? _credit;

  /// Play'den gelen yerelleştirilmiş fiyat (yoksa ARB'deki 'price' gösterilir).
  String? get playPrice => billing?.price;

  /// Paket fiyatı (Play); ürün Play Console'da yoksa null → paket kartı gösterilmez.
  String? get bundlePrice => billing?.bundlePrice;

  /// Paket tasarruf yüzdesi, Play fiyatlarından hesaplanır (ör. 25); hesaplanamazsa null.
  int? get bundleSavePct {
    final b = billing;
    if (b == null) return null;
    return bundleSavingsPercent(
      single: b.singleRaw,
      bundle: b.bundleRaw,
      singleCurrency: b.singleCurrency,
      bundleCurrency: b.bundleCurrency,
      rights: rightsFor(kBundleProductId),
    );
  }

  bool get billingReady => billing?.available ?? false;

  /// Ödeme yapmadan yayınlanabilir: tüketilmemiş alım ya da sunucuda paket hakkı var.
  bool get hasCredit => _credit != null || creditBalance > 0;

  /// Tüketilmemiş (sunucunun henüz bir davetiyeye bağlamadığı) tekli alım.
  bool get hasUnconsumed => _credit != null;

  /// Ücretli yayın düğmesi çalışır mı: Play hazır ya da kullanılabilir paket hakkı var.
  bool get canPayOrUseCredit => billingReady || creditBalance > 0;

  /// Ödeme alındı ama sunucu henüz hak vermedi (Play beklemede ya da doğrulama yapılamadı):
  /// ana ekranda "Ödemeniz doğrulanıyor…" bandı + "Tekrar dene".
  bool _payVerifying = false;
  bool get payVerifying => _payVerifying;

  bool _restoring = false;
  bool get restoring => _restoring;

  void _setVerifying(bool v) {
    if (_payVerifying == v) return;
    _payVerifying = v;
    notifyListeners();
  }

  /// "Satın alımı geri yükle": Play'deki tüketilmemiş alımları yeniden sorgular, her birini sunucuda
  /// doğrulatır (redeemPurchase → hak verilince tüket). Dönen değer: kullanıcı metni ARB anahtarı.
  Future<String> restorePurchases() async {
    final b = billing;
    final c = cloud;
    if (b == null || !await b.ensureAvailable()) return 'payUnavailable';
    if (c == null || !c.ready) return 'cloudSetup';
    if (_restoring) return 'restorePending';
    _restoring = true;
    notifyListeners();
    try {
      final q = await b.query();
      if (q == null) return restoreMessageKey(const [], queryFailed: true);
      final results = <String?>[];
      for (final p in q.owned) {
        results.add(await _handleBought(p));
      }
      _setVerifying(needsVerifyBanner(results, pending: q.pending));
      await refreshCredits();
      final key = restoreMessageKey(results, pending: q.pending);
      // Paket hakları sunucuda duruyorsa (aynı uid) kalan sayı söylenir.
      if (creditBalance > 0 && (key == 'restoreDone' || key == 'restoreNone')) return 'restoreCreditsLeft';
      return key;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Açılışta: alım akışını dinle, fiyatı yükle, tüketilmemiş alımları tamamla (hak ver → tüket).
  Future<void> startBilling() async {
    final b = billing;
    if (b == null) return;
    try {
      _pending = await _store.loadPendingPaid();
      await b.init(_onPurchase);
      notifyListeners(); // fiyat / kullanılabilirlik
      if (!b.available) return;
      final q = await b.query();
      if (q == null) return;
      final results = <String?>[];
      for (final p in q.owned) {
        results.add(await _handleBought(p));
      }
      _setVerifying(needsVerifyBanner(results, pending: q.pending));
    } catch (e, st) {
      StartupLog.record('billing.start', e, st);
    }
  }

  /// Ücretli yayın (yayınla ekranı). Dönen değer: null (yayında), 'paidPhotoErr' (yayında, fotoğraf eksik)
  /// ya da hata metin anahtarı. [productId]: satın alma gerekirse hangi ürün (tekli ya da "Düğün Zinciri").
  /// Sıra (paidRouteFor): tüketilmemiş alım > sunucudaki paket hakkı (satın almasız) > Play satın alma.
  Future<String?> publishPaid(Invitation inv, {String productId = kInviteProductId}) async {
    final c = cloud;
    final b = billing;
    if (c == null || !c.ready) return 'cloudSetup';
    final billingOk = b != null && b.available;
    if (!billingOk && creditBalance <= 0) return 'payUnavailable';
    if (_buyWait != null || _creditBusy) return 'payProcessing';
    inv
      ..n1 = cloudSafeName(inv.n1)
      ..n2 = cloudSafeName(inv.n2)
      ..nameEditsLeft = kNameEdits
      ..dateEditsLeft = kDateEdits;
    final String uid;
    try {
      uid = await c.ensureUser();
    } on CloudError catch (e) {
      return e.key;
    }
    final prev = _pending;
    // Ücretsiz yayındaki (süresi dolmuş olabilir) davetiye aynı bağlantıyla yükseltilir: aynı bulut kimliği.
    final upgradeId = canUpgradeToPaid(inv) ? inv.cloudId : null;
    final ctx = (prev != null && prev.invId == inv.id && (upgradeId == null || prev.cloudId == upgradeId))
        ? prev
        : PendingPaid(invId: inv.id, cloudId: upgradeId ?? generateInviteId());
    _pending = ctx;
    await _store.savePendingPaid(ctx);

    // Kullanılmamış hak varsa yeniden satın alınmaz (tüketilmemiş alım varken Play yeni alıma izin vermez).
    final credit = billingOk ? (_credit ?? _firstOrNull(await b!.owned())) : null;
    final route = paidRouteFor(balance: creditBalance, hasUnconsumed: credit != null);
    if (route == PaidRoute.unconsumed) {
      _credit = null;
      return _handleBought(credit!);
    }
    if (route == PaidRoute.serverCredit) {
      final used = await _useServerCredit(inv, ctx);
      // Sunucuda hak kalmamışsa (başka cihazda kullanıldı / iade) satın almaya geçilir.
      if (used != 'creditNone' || !billingOk) return used;
    }

    final wait = Completer<String?>();
    _buyWait = wait;
    final started = await b!.buy(productId: productId, accountId: uid);
    if (!started) {
      _buyWait = null;
      return 'payUnavailable';
    }
    // Sonuç alım akışından gelir (_onPurchase). Kullanıcı Play penceresinde beklerse süre sınırı geniş.
    final r = await wait.future.timeout(const Duration(minutes: 15), onTimeout: () => 'payPending');
    _buyWait = null;
    return r;
  }

  static BillingPurchase? _firstOrNull(List<BillingPurchase> l) => l.isEmpty ? null : l.first;

  /// "Zaten sahipsiniz" hatasında: denenen ürünün tüketilmemiş alımı, yoksa herhangi biri.
  static BillingPurchase? _ownedFor(List<BillingPurchase> l, String productId) {
    for (final p in l) {
      if (p.productId == productId) return p;
    }
    return _firstOrNull(l);
  }

  /// Paket hakkıyla yayın (useCredit). Bağlam (bulut kimliği) önceden saklandığı için yeniden denemede
  /// sunucu aynı davetiyeye ikinci hak düşmez.
  Future<String?> _useServerCredit(Invitation inv, PendingPaid ctx) async {
    final c = cloud;
    if (c == null) return 'cloudSetup';
    _creditBusy = true;
    try {
      final warn = await c.publishWithCredit(inv, inviteId: ctx.cloudId, onCredits: _setCredits);
      await _clearPending();
      _payVerifying = false;
      premiumUser = true;
      await _store.savePremiumUser(true);
      await save();
      return warn;
    } on RedeemFailure catch (f) {
      if (f.key == 'creditNone') _setCredits(0);
      return f.key;
    } catch (e) {
      debugPrint('credit publish failed: $e');
      return 'payVerifyErr';
    } finally {
      _creditBusy = false;
    }
  }

  void _finishWait(String? result) {
    final w = _buyWait;
    if (w != null && !w.isCompleted) w.complete(result);
  }

  Future<void> _onPurchase(BillingPurchase p) async {
    try {
      await _onPurchaseInner(p);
    } catch (e, st) {
      StartupLog.record('billing.purchase', e, st);
      _finishWait('payErr');
    }
  }

  Future<void> _onPurchaseInner(BillingPurchase p) async {
    final b = billing;
    if (b == null) return;
    if (!kProductIds.contains(p.productId)) {
      await b.complete(p);
      return;
    }
    switch (p.status) {
      case BillingStatus.pending:
        _setVerifying(true);
        _finishWait('payPending'); // bağlam saklı: onaylanınca akıştan "purchased" gelir ve yayınlanır
      case BillingStatus.canceled:
        _finishWait('payCancelled');
      case BillingStatus.error:
        if (p.alreadyOwned) {
          final o = _ownedFor(await b.owned(), p.productId);
          if (o != null) {
            await _handleBought(o); // sonucu bekleyen ekrana kendisi iletir
            return;
          }
        }
        _finishWait('payErr');
      case BillingStatus.purchased:
        await _handleBought(p);
    }
  }

  /// Satın alınmış (tüketilmemiş) alımı işler: bağlamdaki taslağı ücretli yayınlar ya da (bağlam yoksa)
  /// sunucuya daha önce hak verilip verilmediğini sorar. Tüketme yalnız sunucu hakkı verdikten sonra.
  /// Sonuç, satın alma sonucunu bekleyen yayınla ekranına da iletilir (açılıştaki tamamlama dahil).
  Future<String?> _handleBought(BillingPurchase p) async {
    if (!_inFlight.add(p.token)) return 'payProcessing'; // aynı alım zaten işleniyor; sonucu o iletecek
    final r = await _processBought(p);
    _inFlight.remove(p.token);
    if (isUnverifiedResult(r)) _setVerifying(true);
    _finishWait(r);
    return r;
  }

  Future<String?> _processBought(BillingPurchase p) async {
    final c = cloud;
    final b = billing;
    if (c == null || b == null) return 'cloudSetup';
    try {
      final ctx = _pending;
      final inv = ctx == null ? null : byId(ctx.invId);
      if (ctx != null && inv != null && (!inv.isLive || (canUpgradeToPaid(inv) && inv.cloudId == ctx.cloudId))) {
        final warn = await c.publishPaid(inv,
            purchaseToken: p.token, inviteId: ctx.cloudId, productId: p.productId, onCredits: _setCredits);
        await _granted(p);
        return warn;
      }
      // Bağlam yok (açılış / geri yükleme): tekli alımda sunucu daha önce hak verdiyse başarı; paket alımında
      // 3 hak deftere yazılır (davetiyeye bağlanmadan) ve alım tüketilir.
      final bal = await c.redeemGranted(p.token, productId: p.productId);
      if (bal != null) _setCredits(bal);
      await _granted(p);
      return null;
    } on RedeemFailure catch (f) {
      switch (f.action) {
        case RedeemAction.consume:
          await b.consume(p);
          await _clearPending();
        case RedeemAction.keep:
          if (f.key == 'payCredit') _credit = p;
        case RedeemAction.drop:
          await _clearPending();
      }
      notifyListeners();
      return f.key;
    } catch (e) {
      debugPrint('paid publish failed: $e');
      return 'payVerifyErr';
    }
  }

  Future<void> _granted(BillingPurchase p) async {
    if (_credit?.token == p.token) _credit = null;
    await billing?.consume(p); // başarısızsa sonraki açılışta sunucu idempotent döner, yeniden tüketilir
    await _clearPending();
    _payVerifying = false;
    premiumUser = true;
    await _store.savePremiumUser(true);
    await save();
  }

  Future<void> _clearPending() async {
    _pending = null;
    await _store.savePendingPaid(null);
  }

  /// Yayındaki davetiyeyi buluta yaz ("Güncelle"). Dönen değer: null ya da hata metin anahtarı.
  Future<String?> pushUpdate(Invitation inv) async {
    if (!inv.isLive || inv.cloudId == null) return 'cloudGone';
    if (isExpired(inv)) return 'expiredNote';
    if (inv.plan != 'premium' && (kThemes[inv.theme]?.premium ?? false)) return 'premThemeNeed';
    final c = cloud;
    if (c == null || !c.ready) return 'cloudSetup';
    try {
      await c.update(inv);
      return null;
    } on CloudError catch (e) {
      return e.key;
    } finally {
      await save(); // fotoğraf eşlemesi (cloudFiles) değişmiş olabilir
    }
  }

  // ---- Fotoğraflar ----
  File photoFile(String name) => _photos.fileFor(name);

  Future<String> photoDataUri(String name) => _photos.dataUri(name);

  /// Kapak ayarla. Dönen değer: null (başarılı) ya da hata metin anahtarı.
  Future<String?> setCover(Invitation inv, Uint8List bytes) async {
    String name;
    try {
      name = await _photos.saveBytes(bytes);
    } on FileSystemException {
      return 'quota';
    } catch (_) {
      return 'photoErr';
    }
    final old = inv.cover;
    inv.cover = name;
    if (!await save()) {
      inv.cover = old;
      await _photos.delete(name);
      await save();
      return 'quota';
    }
    await _photos.delete(old);
    return null;
  }

  Future<void> removeCover(Invitation inv) async {
    final old = inv.cover;
    inv.cover = '';
    await save();
    await _photos.delete(old);
  }

  /// Galeriye ekle (en çok 6). Dönen değer: null ya da uyarı metin anahtarı.
  Future<String?> addPhotos(Invitation inv, List<Uint8List> items) async {
    final room = kMaxGallery - inv.photos.length;
    if (room <= 0) return 'galFull';
    String? warn = items.length > room ? 'galFull' : null;
    for (final bytes in items.take(room)) {
      String name;
      try {
        name = await _photos.saveBytes(bytes);
      } on FileSystemException {
        return 'quota';
      } catch (_) {
        warn = 'photoErr';
        continue;
      }
      inv.photos.add(name);
      if (!await save(notify: false)) {
        inv.photos.removeLast();
        await _photos.delete(name);
        await save(notify: false);
        warn = 'quota';
        break;
      }
    }
    notifyListeners();
    return warn;
  }

  Future<void> removePhoto(Invitation inv, int i) async {
    if (i < 0 || i >= inv.photos.length) return;
    final name = inv.photos.removeAt(i);
    await save();
    await _photos.delete(name);
  }

  Future<void> movePhotoEarlier(Invitation inv, int i) async {
    if (i <= 0 || i >= inv.photos.length) return;
    final x = inv.photos[i];
    inv.photos[i] = inv.photos[i - 1];
    inv.photos[i - 1] = x;
    await save();
  }

  /// Davetli sayfasına gidecek veri (fotoğraflar data URI).
  Future<Map<String, dynamic>> inviteData(Invitation inv) async {
    final cover = await _photos.dataUri(inv.cover);
    final photos = <String>[];
    for (final p in inv.photos) {
      final d = await _photos.dataUri(p);
      if (d.isNotEmpty) photos.add(d);
    }
    // Önizlemede ücretli olacak taslak da ücretli görünsün (hediye IBAN'ı kartı için).
    return inv.toInviteData(coverSrc: cover, photoSrcs: photos, planOverride: isPaidInvite(inv) ? 'premium' : inv.plan);
  }
}
