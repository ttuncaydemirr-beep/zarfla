/// Reklam kimlikleri TEK yerde. Şimdilik Google'ın resmî TEST kimlikleri (para kazandırmaz, hesap riski yok).
///
/// TODO(yayın öncesi): AdMob'dan alınan GERÇEK kimliklerle değiştirin (adımlar: ads_setup.md):
///  - [kAdMobAndroidAppId]  → AdMob > Uygulamalar > Zarfla > Uygulama kimliği (ca-app-pub-XXXX~YYYY)
///  - [kBannerAdUnitId]     → AdMob > Reklam birimleri > Banner > Reklam birimi kimliği (ca-app-pub-XXXX/ZZZZ)
/// Uygulama kimliği AndroidManifest'e scripts/patch_android.py ile BU dosyadan okunarak yazılır;
/// yani değişiklik yalnız bu iki satırdadır. (patch_android.py satırı `kAdMobAndroidAppId = '...'` biçiminde arar;
/// biçimi bozmayın.)
const String kAdMobAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';

/// Uyarlanabilir (adaptive) banner için Google test birimi.
const String kBannerAdUnitId = 'ca-app-pub-3940256099942544/9214589741';
