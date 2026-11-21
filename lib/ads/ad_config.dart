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

/// Test reklamı zorlama bayrağı (denetim N-6): `--dart-define=ZARFLA_TEST_ADS=true` ile derlenen sürüm, RELEASE olsa bile
/// Google test banner birimini kullanır. Dahili/kapalı test (internal/alpha) derlemelerinde testçilerin ve ailenin
/// kazara gerçek reklama dokunup AdMob "geçersiz trafik" uyarısı/askıya alma riski doğmasın diye CI bunu açar.
/// ÜRETİM (production) derlemesi bu bayrak OLMADAN yapılmalıdır (README "Reklam: test ve üretim derlemesi").
const bool kTestAds = bool.fromEnvironment('ZARFLA_TEST_ADS', defaultValue: false);

/// Birim seçimi (saf işlev, test edilir): gerçek birim yalnız release ve test bayrağı kapalıyken.
String bannerAdUnitIdFor({required bool release, required bool testAds}) =>
    (release && !testAds) ? kBannerAdUnitIdRelease : _kBannerTest;

/// Yalnız yayın (release) derlemesinde ve test bayrağı kapalıyken gerçek birim; diğer her durumda test birimi.
const String kBannerAdUnitId = (kReleaseMode && !kTestAds) ? kBannerAdUnitIdRelease : _kBannerTest;
