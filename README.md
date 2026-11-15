# Zarfla

Demir Games Studio'nun dijital davetiye uygulaması (Flutter, Android).
Paket adı: `com.demirgamesstudio.zarfla` · Diller: Türkçe, English, Deutsch, العربية

## Yapı

```
lib/
  main.dart, app.dart        Başlangıç, MaterialApp (4 dil, Arapça otomatik sağdan sola)
  data/catalog.dart          43 tasarım (renkler birebir), REC sıraları, 19 etkinlik türü, hazır mesajlar
  models/invitation.dart     Davetiye modeli (web önizlemesindeki alanlar)
  logic/                     Doğrulama, yayın sonrası kilit kuralları, tarih ve metin yardımcıları
  l10n/strings.dart          ARB metinlerini okur (assets/l10n/app_<dil>.arb)
  state/app_state.dart       Uygulama durumu (provider + ChangeNotifier)
  storage/                   Taslaklar (shared_preferences), fotoğraflar (belgeler klasörü)
  cloud/invite_contract.dart Veri sözleşmesi (Firestore/Storage alanları, kimlik, bağlantı, süreler) — saf Dart
  cloud/cloud_service.dart   Firebase: anonim giriş, yayınla/güncelle/sil (transaction + Storage)
  firebase_options.dart      Firebase ayarları (google-services.json'dan elle)
  screens/                   Davetiyelerim, Tür, Tasarım, Editör, Yayınla, Hazır, Davetli görünümü
  widgets/                   Ortak bileşenler, süsler, reklam yeri, webview önizleme
assets/
  invite/invite.html         Davetli sayfası: TEK KAYNAK (uygulama önizlemesi + Aşama 2 web sitesi)
  ornaments/*.svg            Tasarım süsleri
  l10n/*.arb                 Arayüz metinleri (4 dil)
  fonts/                     CI'da indirilir (Fraunces, Manrope, Noto Naskh Arabic, Amiri + OFL lisansları)
  branding/android/res/      Uygulama simgesi (CI'da android/app/src/main/res/ içine kopyalanır)
  branding/play/             Play Console 512 px simge (uygulamaya paketlenmez)
android/app/google-services.json   Firebase yapılandırması (proje zarfla-37da9)
firestore.rules, storage.rules     Güvenlik kuralları · firebase.json, .firebaserc (proje zarfla-37da9)
rules-test/                  Kural testleri (CI'da Firebase emülatöründe, "rules" işi)
scripts/                     fetch_fonts.sh, prepare_android.sh, patch_android.py
```

`android/` klasörünün geri kalanı CI'da `flutter create` ile, kurulu Flutter sürümünün
güncel şablonundan üretilir ve `scripts/patch_android.py` ile Zarfla ayarları uygulanır
(uygulama adı, SDK sürümleri, `com.google.gms.google-services` eklentisi — Kotlin DSL ve Groovy —,
uygulama simgesi).

## Aşamalar

1. **Aşama 1:** Firebase'siz, cihazda çalışan uygulama. Ücretli yayın SAHTE
   (ödeme alınmaz, test için yayınlanmış sayılır). Reklam yalnız yer tutucu.
2. **Aşama 2 (şimdi):** Firebase (davetiyeler buluta), davetli sayfası stüdyo sitesinde
   (`https://ttuncaydemirr-beep.github.io/davetiye/?id=<id>`), aynı `invite.html` ile.
   Ücretsiz yayın çalışır; ücretli yayın "yakında" (Aşama 3).
3. **Aşama 3:** Google Play Faturalandırma (aşağıda), AdMob banner, gerçek imza ve Play yüklemesi.

## APK'yı telefondan indirme

1. GitHub uygulamasında ya da tarayıcıda depoyu açın → **Actions** sekmesi.
2. En üstteki yeşil (✓) **Derleme** çalışmasına dokunun.
3. Sayfanın altındaki **Artifacts** bölümünden `zarfla-debug-apk` dosyasını indirin (imzalı AAB için aşağıdaki "İmzalı sürüm" bölümüne bakın).
4. İnen ZIP'i açın, `app-debug.apk` dosyasını kurun (bilinmeyen kaynaklara izin vermeniz istenebilir).

Elle derleme başlatmak için: Actions → Derleme → **Run workflow**.

## İmzalı sürüm

- **Anahtar şifreli depoda:** Yükleme anahtarı `android-signing/upload.jks.enc` olarak durur (AES-256-CBC, PBKDF2 200000 tur; takma ad `zarfla`, sahip `CN=Demir Games Studio`). Düz `.jks` ve `key.properties` asla depoya girmez (`.gitignore`).
- **Parola secret'ta:** GitHub Actions secret'ı `SIGNING_PASSPHRASE` (hem şifre çözme hem keystore/key parolası). CI anahtarı geçici olarak çözer, `android/key.properties` yazar, derlemeden sonra siler. Secret yoksa (ör. fork) debug imzayla derler ve uyarır; bu AAB Play'e yüklenemez.
- **Sürüm:** `versionName` 1.0.0 (`pubspec.yaml`), `versionCode` = `github.run_number + 100` (her derlemede artar).
- **Çıktı:** Actions → Derleme → Artifacts → `zarfla-release-aab-signed` (14 gün). CI imza sahibini ve SHA-1/SHA-256 parmak izlerini loga yazar; parmak izleri gizli değildir.
- **R8 küçültme + gizleme açık** (`android/app/proguard-rules.pro`, `patch_android.py` bağlar). Her derleme `zarfla-r8-mapping` (mapping.txt) ve `zarfla-dart-symbols` artifact'larını saklar; Play'e yükleme işi mapping'i otomatik gönderir. Elle yüklemede: Play Console > Uygulama paketi gezgini > ilgili sürüm > Yükle > Yeniden eşleme (deobfuscation) dosyası.
- **Play App Signing kullanılacak:** Play Console'a bu anahtarla imzalı AAB yüklenir; Google uygulama imza anahtarını kendisi tutar, bizim anahtarımız yalnızca *yükleme anahtarı*dır.
- **Anahtar kaybı:** Parola ya da anahtar kaybolursa Play Console → Uygulama bütünlüğü → Uygulama imzalama → **Yükleme anahtarını sıfırla** ile yeni yükleme anahtarı tanımlanır (uygulama imzası etkilenmez). Parolayı güvenli bir yerde yedekleyin.

## Yerelde derleme (bilgisayar varsa)

```
bash scripts/fetch_fonts.sh
bash scripts/prepare_android.sh
flutter pub get && flutter test && flutter run
```

## Firebase (Aşama 2)

**Veri sözleşmesi** (`lib/cloud/invite_contract.dart`; davetli sayfası da buna göre okur):

- Firestore `invites/{id}` — `id`: 12 karakter `[A-Za-z0-9]`, `Random.secure`.
- Alanlar: `ownerUid`, `schema` (1), `data` (davetli sayfası JSON'u, fotoğraflar Storage URL'leri),
  `plan` (`free`|`paid`), `status` (`live`), `createdAt` (sunucu saati), `expiresAt`
  (free +24 saat, paid +365 gün), `deleteAt` (expiresAt +30 gün, TTL), kilit alanları
  `type, theme, n1, n2, date, origDate, nameEdits, dateEdits`.
- Storage: `invites/{id}/cover.<uzantı>`, `g1…g6.<uzantı>` (< 2 MB, `image/*`).
- Bağlantı: `https://ttuncaydemirr-beep.github.io/davetiye/?id={id}`; sayfa belgeyi anahtarsız okur:
  `GET https://firestore.googleapis.com/v1/projects/zarfla-37da9/databases/(default)/documents/invites/{id}`
  → `fields.data.stringValue` (süresi dolmuşsa 403, hiç yoksa 404).

**Akış:** Yayınla → belge oluştur (transaction; çevrimdışıyken kuyruğa girmez, hata verir) →
fotoğrafları yükle → `data`'yı URL'lerle güncelle → bağlantı. Güncelle → değişen fotoğraflar yüklenir,
kaldırılanlar silinir, belge güncellenir. Sil → önce Storage dosyaları, sonra belge.
Aynı anda en fazla 1 aktif ücretsiz davetiye (istemci denetimi).

### Firebase konsolunda yapılacaklar

1. **Authentication** → Başlayın → Oturum açma yöntemi → **Anonim** → Etkinleştir → Kaydet.
2. **Firestore Database** → Veritabanı oluştur → Konum **eur3 (Europe)** ya da **europe-west3
   (Frankfurt)** → **Üretim modunda başlat** → Oluştur. Sonra **Kurallar** sekmesi → içeriği silip
   `firestore.rules` dosyasını yapıştırın → **Yayınla**.
3. **Storage** → Başlayın → aynı AB konumu → Üretim modu → Bitti. **Kurallar** sekmesi →
   `storage.rules` dosyasını yapıştırın → **Yayınla** (Firestore okuma izni isterse **İzin ver**).
   Not: Storage, Blaze (kullandıkça öde) planı isteyebilir.
4. **TTL politikası** (süresi biten belgeler kendiliğinden silinsin): Google Cloud Console →
   proje `zarfla-37da9` → **Firestore** → **Time-to-live (TTL)** → **Create policy** →
   Collection group: `invites`, Timestamp field: `deleteAt` → Create.
   (Doğrudan adres: `https://console.cloud.google.com/firestore/databases/-default-/ttl?project=zarfla-37da9`)
5. (Önerilir) Storage'da sahipsiz kalan fotoğraflar için Cloud Console → **Cloud Storage** → Buckets →
   `zarfla-37da9.firebasestorage.app` → **Lifecycle** → Add rule → Delete object, Age **400** gün.
   (Aşama 3: `cleanupStorage` fonksiyonu bunu her gün yapar; kural yine yedek olarak kalabilir.)

### Kural test planı

CI'daki **rules** işi `rules-test/rules.test.mjs` ile aşağıdakilerin hepsini emülatörde çalıştırır.

| # | Durum | Beklenen |
|---|-------|----------|
| C1 | Anonim kullanıcı geçerli ücretsiz belge oluşturur | izin |
| C2 | Oturumsuz oluşturma | ret |
| C3 | ownerUid başka kullanıcı | ret |
| C4 | plan = "paid" | ret |
| C5 | expiresAt > şimdi + 25 saat | ret |
| C20 | expiresAt > şimdi + 24 saat 10 dk (saat farkı payı) | ret |
| C21 | expiresAt geçmişte | ret |
| C22 | Tam tutarlı ücretli belgeyi istemci oluşturur | ret |
| U9 | Ücretsizden ücretliye tutarlı yükseltme (istemci) | ret |
| PD1 | Sunucunun (redeemPurchase) yazdığı ücretli belgeyi sahibi fotoğraf/isimle günceller; tasarım kilidi | izin/ret |
| US1 | users/{uid}: yalnız kendisi okur, kimse yazamaz | izin/ret |
| PU1 | purchases/*: istemciye kapalı | ret |
| C6 | Listede olmayan ek alan | ret |
| C7 | nameEdits ya da dateEdits ≠ 0 | ret |
| C8 | origDate ≠ date | ret |
| C9 | Ücretsiz planda ücretli tasarım | ret |
| C10 | data.id ≠ belge kimliği | ret |
| C11 | data'da ikinci "theme" anahtarı | ret |
| C12 | `e` kaçışıyla gizlenmiş anahtar | ret |
| C13 | data.n1 ≠ n1 | ret |
| C14 | Ücretsiz belgede data.plan = "premium" | ret |
| C15 | Kimlik 12 karakter değil | ret |
| C16 | data ≥ 200 KB | ret |
| C17 | createdAt istemci saati | ret |
| C18 | İsimde çift tırnak | ret |
| C19 | Regex özel karakterli isim | izin |
| T1 | Yeni etkinlik türü + papatya ile ücretsiz oluşturma (11 tür) | izin |
| T2 | Ücretsiz planda yeni tasarım (16 tasarım) | ret |
| T3 | Geçersiz biçimli tür anahtarı (büyük harf, 25 karakter, tire) | ret |
| T4 | Ücretli yeni tasarım + yeni türde isim düzeltme izin; tür/tasarım değişimi ret | izin/ret |
| R1 | Yayındaki belgeyi herkes okur | izin |
| R2 | Süresi dolmuş belgeyi başkası okur | ret |
| R3 | Sahibi süresi dolmuş belgesini okur | izin |
| R4 | Olmayan belgeyi okuma (404) | izin |
| R5 | Koleksiyonu listeleme | ret |
| U1 | Sahibi metin/isim günceller (ücretsiz) | izin |
| U2 | Başkası günceller | ret |
| U3 | expiresAt uzatma | ret |
| U4 | free → paid | ret |
| U5 | origDate/schema/createdAt/ownerUid değiştirme | ret |
| U6 | Ücretsizde sayaç değiştirme | ret |
| U7 | Ücretsizde tarih değiştirme (data ile) | izin |
| U8 | data ile üst düzey alan uyumsuz | ret |
| P1 | Ücretli: isim + nameEdits +1 | izin |
| P2 | Ücretli: isim, sayaç aynı | ret |
| P3 | Ücretli: sayaç +2 | ret |
| P4 | Ücretli: 3 hak bitti | ret |
| P5 | Ücretli: tasarım / tür değiştirme | ret |
| P6 | Ücretli: tarih +30 gün, dateEdits +1 | izin |
| P7 | Ücretli: tarih +61 gün | ret |
| P8 | Ücretli: tarih −60 gün | izin |
| P9 | Ücretli: 2 tarih hakkı bitti | ret |
| P10 | Ücretli: süre uzatma | ret |
| D1 | Sahibi siler | izin |
| D2 | Başkası / oturumsuz siler | ret |
| S1 | Sahibi kapak ve galeri yükler | izin |
| S2 | Başkası / oturumsuz yükler | ret |
| S3 | Belge yokken yükleme | ret |
| S4 | image/* olmayan içerik | ret |
| S5 | İzinsiz dosya adı (g7, .html) | ret |
| S6 | ≥ 2 MB | ret |
| S7 | Herkes okur, yalnız sahibi siler | izin/ret |

**Kuralların sınırı:** kurallar JSON ayrıştıramaz; `data` metni kilit alanlarına düzenli ifadelerle
bağlanır (önek, tek anahtar, birebir değer). "Aynı anda 1 ücretsiz davetiye" sınırını kurallar sayamaz:
istemci engeller, sunucuda `enforceFreeLimit` fonksiyonu yeni fazlalığı kapatır (anonim hesapta yeniden
kurulumla aşılabilir; kabul edilen risk).

## Aşama 3: Google Play Faturalandırma ve sunucu fonksiyonları

**Ürün:** `zarfla_invite_1` — tek seferlik, **tüketilebilir** "1 Davetiye Hakkı" (abonelik yok).
Ücretsiz: yalnız Papatya, 24 saat, alt yazı. Ücretli: tüm tasarımlar, 365 gün, alt yazı yok, hesap bir daha
reklam görmez (`premiumUser`; sunucuda `users/{uid}.premium`).

**Akış (uygulama):** Yayınla → ücretli → bağlam kaydedilir (taslak + önceden seçilen bulut kimliği) →
tüketilmemiş eski alım varsa o kullanılır, yoksa Play satın alma (`autoConsume: false`) → jeton →
`redeemPurchase` (europe-west3) → başarıda fotoğraflar yüklenir, alım **tüketilir**. Bekleyen ödeme
onaylanınca, ya da uygulama açılışında tüketilmemiş alım bulunursa, aynı bağlamla tamamlanır (sunucu
idempotent: aynı jeton + aynı davetiye = yine başarı). Kod: `lib/billing/`, `CloudService.publishPaid`,
`AppState.publishPaid/startBilling`.

**Fonksiyonlar** (`functions/`, Node 22, düz JS, çalışma kimliği `zarfla-functions@zarfla-37da9.iam.gserviceaccount.com`):

| Fonksiyon | Tetik | İş |
|---|---|---|
| `redeemPurchase` | callable (oturum şart) | `purchases.products.get` ile doğrular (purchaseState 0, tüketilmemiş), `purchases/{sha256(jeton)}` kaydı (ham jeton saklanmaz), `invites/{id}` plan `paid`, +365 gün, deleteAt +395 gün, `users/{uid}.premium=true`, gerekirse acknowledge |
| `voidedPurchases` | her gün 04:23 (İstanbul) | Son 30 günün iade/geri ödemeleri: alım `voided`, davetiye **en geç 24 saat içinde kapanır** (silinmez, plan/tasarım korunur), başka geçerli alım yoksa premium kalkar |
| `enforceFreeLimit` | `invites/{id}` oluşturulunca | Aynı sahibin açık başka ücretsizi varsa yenisi hemen kapanır |
| `cleanupStorage` | her gün 04:41 (İstanbul) | TTL ile silinmiş / deleteAt'i geçmiş davetiyelerin Storage dosyaları |

**Kurallar:** istemci `paid` oluşturamaz/yükseltemez (yalnız Admin SDK); ücretsiz süre en çok 24 saat + 10 dk.
**CI:** `functions` işi (`npm run verify`: sözdizimi + sahte Play API ile birim testleri + yükleme).
**Yayın:** Actions → **Sunucu yayını (Functions + kurallar)** → Run workflow (secret `FIREBASE_DEPLOY_SA`).
