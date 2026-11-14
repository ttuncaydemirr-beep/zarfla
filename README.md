# Zarfla

Demir Games Studio'nun dijital davetiye uygulaması (Flutter, Android).
Paket adı: `com.demirgamesstudio.zarfla` · Diller: Türkçe, English, Deutsch, العربية

## Yapı

```
lib/
  main.dart, app.dart        Başlangıç, MaterialApp (4 dil, Arapça otomatik sağdan sola)
  data/catalog.dart          17 tasarım (renkler birebir), REC sıraları, etkinlik türleri, hazır mesajlar
  models/invitation.dart     Davetiye modeli (web önizlemesindeki alanlar)
  logic/                     Doğrulama, yayın sonrası kilit kuralları, tarih ve metin yardımcıları
  l10n/strings.dart          ARB metinlerini okur (assets/l10n/app_<dil>.arb)
  state/app_state.dart       Uygulama durumu (provider + ChangeNotifier)
  storage/                   Taslaklar (shared_preferences), fotoğraflar (belgeler klasörü)
  screens/                   Davetiyelerim, Tür, Tasarım, Editör, Yayınla, Hazır, Davetli görünümü
  widgets/                   Ortak bileşenler, süsler, reklam yeri, webview önizleme
assets/
  invite/invite.html         Davetli sayfası: TEK KAYNAK (uygulama önizlemesi + Aşama 2 web sitesi)
  ornaments/*.svg            Tasarım süsleri
  l10n/*.arb                 Arayüz metinleri (4 dil)
  fonts/                     CI'da indirilir (Fraunces, Manrope, Noto Naskh Arabic, Amiri + OFL lisansları)
android/app/google-services.json   Firebase yapılandırması (Aşama 2'de bağlanacak)
scripts/                     fetch_fonts.sh, prepare_android.sh, patch_android.py
```

`android/` klasörünün geri kalanı CI'da `flutter create` ile, kurulu Flutter sürümünün
güncel şablonundan üretilir ve `scripts/patch_android.py` ile Zarfla ayarları uygulanır.

## Aşamalar

1. **Aşama 1 (şimdi):** Firebase'siz, cihazda çalışan uygulama. Ücretli yayın SAHTE
   (ödeme alınmaz, test için yayınlanmış sayılır). Reklam yalnız yer tutucu.
2. **Aşama 2:** Firebase (davetiyeler buluta), davetli sayfası stüdyo sitesinde
   (`ttuncaydemirr-beep.github.io/davet/<id>`), aynı `invite.html` ile.
3. **Aşama 3:** Google Play Faturalandırma, AdMob banner, gerçek imza ve Play yüklemesi.

## APK'yı telefondan indirme

1. GitHub uygulamasında ya da tarayıcıda depoyu açın → **Actions** sekmesi.
2. En üstteki yeşil (✓) **Derleme** çalışmasına dokunun.
3. Sayfanın altındaki **Artifacts** bölümünden `zarfla-debug-apk` dosyasını indirin.
4. İnen ZIP'i açın, `app-debug.apk` dosyasını kurun (bilinmeyen kaynaklara izin vermeniz istenebilir).

Elle derleme başlatmak için: Actions → Derleme → **Run workflow**.

## Yerelde derleme (bilgisayar varsa)

```
bash scripts/fetch_fonts.sh
bash scripts/prepare_android.sh
flutter pub get && flutter test && flutter run
```
