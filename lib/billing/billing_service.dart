import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'billing_logic.dart';

enum BillingStatus { pending, purchased, canceled, error }

/// Uygulamanın geri kalanı eklenti türlerini görmez: yalnız bu sade alım nesnesi.
class BillingPurchase {
  BillingPurchase._(this._raw, this.status, {this.alreadyOwned = false});

  final PurchaseDetails _raw;
  final BillingStatus status;

  /// Play "ürün zaten sahipli" hatası (tüketilmemiş eski alım var).
  final bool alreadyOwned;

  String get productId => _raw.productID;

  /// Android'de Google Play satın alma jetonu (purchaseToken).
  String get token => _raw.verificationData.serverVerificationData;
}

/// Google Play Faturalandırma (resmî `in_app_purchase` eklentisi). Yalnız Android.
/// Ürün tüketilebilir: `autoConsume: false` ile satın alınır, sunucu hak verdikten sonra [consume] çağrılır.
class BillingService {
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _available = false;

  bool get available => _available;

  /// Play'in yerelleştirilmiş fiyatı (ör. "₺399,00"); ürün yüklenmediyse null.
  String? get price => _product?.price;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  InAppPurchaseAndroidPlatformAddition get _android =>
      InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

  /// Alım akışını dinlemeye başlar (uygulama açılışında bir kez). Hata sessiz: ödeme kullanılamaz sayılır.
  Future<void> init(void Function(BillingPurchase p) onPurchase) async {
    if (!_supported) return;
    try {
      _sub ??= InAppPurchase.instance.purchaseStream.listen(
        (list) {
          for (final p in list) {
            onPurchase(_wrap(p));
          }
        },
        onError: (Object e) => debugPrint('billing stream error: $e'),
      );
      _available = await InAppPurchase.instance.isAvailable();
      if (_available) await loadProduct();
    } catch (e) {
      _available = false;
      debugPrint('billing init failed: $e');
    }
  }

  Future<ProductDetails?> loadProduct() async {
    if (!_supported) return null;
    try {
      final r = await InAppPurchase.instance.queryProductDetails({kInviteProductId});
      for (final p in r.productDetails) {
        if (p.id == kInviteProductId) _product = p;
      }
      if (r.notFoundIDs.isNotEmpty) debugPrint('billing: product not found ${r.notFoundIDs}');
    } catch (e) {
      debugPrint('billing: queryProductDetails failed: $e');
    }
    return _product;
  }

  /// Play satın alma penceresini açar. true: pencere açıldı (sonuç alım akışından gelir).
  /// [accountId]: anonim Firebase uid (Play'e obfuscatedAccountId olarak gider; dolandırıcılık denetimi için).
  Future<bool> buy({String? accountId}) async {
    if (!_supported) return false;
    if (!_available) _available = await InAppPurchase.instance.isAvailable();
    if (!_available) return false;
    final p = _product ?? await loadProduct();
    if (p == null) return false;
    try {
      return await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: p, applicationUserName: accountId),
        autoConsume: false,
      );
    } catch (e) {
      debugPrint('billing: buy failed: $e');
      return false;
    }
  }

  /// Sahip olunan (satın alınmış, henüz tüketilmemiş) Davetiye Hakkı alımları. Beklemedekiler hariç.
  Future<List<BillingPurchase>> owned() async {
    if (!_supported || !_available) return const [];
    try {
      final r = await _android.queryPastPurchases();
      return [
        for (final p in r.pastPurchases)
          if (p.productID == kInviteProductId &&
              p is GooglePlayPurchaseDetails &&
              p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased)
            BillingPurchase._(p, BillingStatus.purchased),
      ];
    } catch (e) {
      debugPrint('billing: queryPastPurchases failed: $e');
      return const [];
    }
  }

  /// Tüketir (aynı zamanda onaylar). YALNIZ sunucu hak verdikten sonra çağrılır. true: başarılı.
  Future<bool> consume(BillingPurchase p) async {
    if (!_supported) return false;
    try {
      final r = await _android.consumePurchase(p._raw);
      if (r.responseCode != BillingResponse.ok) debugPrint('billing: consume ${r.responseCode}');
      return r.responseCode == BillingResponse.ok;
    } catch (e) {
      debugPrint('billing: consume failed: $e');
      return false;
    }
  }

  /// Bu uygulamaya ait olmayan ürünlerin bekleyen işlemini kapatır.
  Future<void> complete(BillingPurchase p) async {
    if (!p._raw.pendingCompletePurchase) return;
    try {
      await InAppPurchase.instance.completePurchase(p._raw);
    } catch (e) {
      debugPrint('billing: completePurchase failed: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static BillingPurchase _wrap(PurchaseDetails p) {
    final s = p.status;
    if (s == PurchaseStatus.pending) return BillingPurchase._(p, BillingStatus.pending);
    if (s == PurchaseStatus.purchased || s == PurchaseStatus.restored) {
      return BillingPurchase._(p, BillingStatus.purchased);
    }
    if (s == PurchaseStatus.canceled) return BillingPurchase._(p, BillingStatus.canceled);
    final msg = '${p.error?.message ?? ''} ${p.error?.details ?? ''}';
    return BillingPurchase._(p, BillingStatus.error, alreadyOwned: msg.contains('itemAlreadyOwned'));
  }
}
