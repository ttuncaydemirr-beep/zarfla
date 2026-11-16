import 'package:flutter/foundation.dart' show kReleaseMode;

/// Reklam kimlikleri TEK yerde. GERÇEK AdMob kimlikleri (Demir Games Studio, pub-3269207938446570).
///
/// Uygulama kimliği AndroidManifest'e scripts/patch_android.py ile BU dosyadan okunarak yazılır.
/// (patch_android.py satırı `kAdMobAndroidAppId = '...'` biçiminde arar; biçimi bozmayın.)
/// app-ads.txt: https://ttuncaydemirr-beep.github.io/app-ads.txt (aynı yayıncı kimliği).
const String kAdMobAndroidAppId = 'ca-app-pub-3269207938446570~8098988341';

/// Gerçek banner birimi: "Zarfla alt banner".
const String kBannerAdUnitIdRelease = 'ca-app-pub-3269207938446570/5079566629';

/// Google'ın resmî uyarlanabilir banner TEST birimi (debug/profil derlemeleri için; hesap riski yok).
const String _kBannerTest = 'ca-app-pub-3940256099942544/9214589741';

/// Yalnız yayın (release) derlemesinde gerçek birim; geliştirme derlemelerinde test birimi.
const String kBannerAdUnitId = kReleaseMode ? kBannerAdUnitIdRelease : _kBannerTest;
