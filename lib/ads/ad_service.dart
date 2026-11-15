import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Reklam başlatma ve rıza (Google UMP) akışı.
/// Sıra: rıza bilgisini iste → gerekiyorsa (AEA/BK) formu göster → ANCAK ondan sonra MobileAds başlat.
/// Kişiselleştirilmemiş reklam kararını UMP/AdMob kendisi uygular; ek izleme eklenmez.
class AdService {
  AdService._();

  /// Reklam yalnız Android'de (ve testlerde/web'de değil) çalışır.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// MobileAds başlatıldı ve reklam istenebilir.
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// "Gizlilik seçenekleri" girişi gösterilmeli mi (UMP gerektiriyorsa).
  static final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier<bool>(false);

  static bool _started = false;
  static bool _sdkInitialized = false;

  /// Uygulama açılışında bir kez çağrılır; beklemeden (arka planda) çalışır.
  static void init() {
    if (!supported || _started) return;
    _started = true;
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            _afterConsent();
          });
        },
        (FormError error) {
          // Ağ yoksa önceki oturumdaki rıza durumu geçerli olabilir.
          _afterConsent();
        },
      );
    } catch (_) {
      // Reklam hatası uygulamayı asla etkilemez.
    }
  }

  /// Menüdeki "Gizlilik seçenekleri": UMP gizlilik seçenekleri formunu açar.
  static void showPrivacyOptions() {
    if (!supported) return;
    try {
      ConsentForm.showPrivacyOptionsForm((FormError? error) {
        _afterConsent();
      });
    } catch (_) {}
  }

  static Future<void> _afterConsent() async {
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired.value = status == PrivacyOptionsRequirementStatus.required;
      if (await ConsentInformation.instance.canRequestAds()) {
        if (!_sdkInitialized) {
          _sdkInitialized = true;
          await MobileAds.instance.initialize();
        }
        ready.value = true;
      } else {
        ready.value = false;
      }
    } catch (_) {
      // Sessizce reklamsız devam.
    }
  }
}
