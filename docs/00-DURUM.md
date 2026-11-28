# Zarfla — Durum

Son güncelleme: 28 Kasım 2026 (Code, güvenlik denetimi dalı `claude/funny-brown-27mqnm`)

## Yayın durumu

| Kanal | Sürüm | Not |
|---|---|---|
| Üretim (herkese açık) | Yok | Üretim başvurusu en erken ~1 Aralık 2026 (14 günlük kapalı test 17 Kasım'da başladı) |
| Kapalı test (alpha) | [Tuncay'a sor: Play Console'daki güncel sürüm] | 17 Kasım'da 1.0.161 incelemedeydi |
| Son Play yüklemesi | 1.0.196 (versionCode 196) | 28 Kasım 2026, Actions çalışması #96; yüklendiği kanal buradan görülemedi [Tuncay'a sor] |

- versionCode = Actions çalışma no + 100; versionName = `1.0.<versionCode>`.
- GitHub'da henüz hiç sürüm etiketi yok.

## Ürün özeti

- **Diller (7):** Türkçe, İngilizce, Almanca, Arapça, İspanyolca, Portekizce (Brezilya), Endonezce. Rusça sonraya bırakıldı.
- **Gelir modeli:** satış + reklam.
  - `zarfla_invite_1` 1 Davetiye Hakkı (399 TL / 9,99 €), `zarfla_invite_3` Düğün Zinciri, 3 hak (899 TL / 22,99 €). Abonelik yok.
  - AdMob banner: Davetiyelerim ve Tasarım galerisinin altında, ödeme yapmayanlara.
- **Altyapı:** Firebase `zarfla-37da9` (Firestore, Storage, Functions, Hosting; europe-west3), App Check izleme kipinde, Play Billing, R8 açık.
- **İçerik:** 43 tasarım, 13 sayfa düzeni, 20 açılış animasyonu, 16 lisanslı müzik.

## Süren işler

| İş | Dal | Kim | Durum |
|---|---|---|---|
| Güvenlik denetimi | `claude/funny-brown-27mqnm` | Code | Aşama 2 bitti: Y-1, Y-2, Y-3, O-3, O-4, D-1 düzeltildi (PR açıldı, Tuncay'ın birleştirme onayı bekleniyor). Kalan bulgular: O-1, O-2 (Sohbet kararı), O-5 (ayrı iş), O-6, D-5, D-6 (Tuncay) |
| CLAUDE.md güncellemesi (Tuncay'ın 28 Kasım kararları: etiket kuralı, ilk yayın kademeli açılış istisnası, Tasarım galerisi banner'ı, hedef yaş 18+, geri dönüş örneği) | `docs/claude-md-28kasim` | Sohbet | PR #2 açık; Code içeriği kontrol etti, Tuncay'ın birleştirme onayı bekleniyor |
| Emülatörde çökme teşhisi iş akışı | `crashcheck` | Code | Yardımcı dal; her sürümde main'e göre güncelleniyor, ana dala birleştirilmiyor |
| Play mağaza bilgileri iş akışı (fiyatlar, çeviriler, görseller) | `playmeta` | Code | main'de olmayan 8 kayıt var [Tuncay'a sor: birleştirilsin mi, yardımcı dal olarak mı kalsın] |
| Mağaza ekran görüntüsü çekme iş akışı | `storeshots` | Code | main'de olmayan 9 kayıt var [Tuncay'a sor: aynı soru] |

Açık PR yok. `docs/kurulum` (PR #1 ile birleşti), `appcheck, bundle, consent, hardening2, hosting, integrate, lang8, layoutfix, longnames, notify, security, stage3-ads, stage3-r8, wave3` dalları tamamen main'e birleşmiş; silinmeleri Tuncay'ın onayına bağlı.

## Sıradaki işler

| # | İş | Kim |
|---|---|---|
| 1 | Güvenlik denetimi PR'ının birleştirilmesi; birleşince bir sonraki derlemede (CI) kilitli paketlerle derlemenin geçtiği görülmeli. Sunucu bir sonraki yayında sabit sürümlerle (firebase-functions 7, firebase-admin 14) çıkar: o yayından sonra ödeme/iade akışı test hesabıyla denenmeli | Tuncay + Code |
| 1a | Güvenlik denetimi kalanları: O-1 (yeniden kurulumda satın alınan hakların kaybı) ve O-2 (cihazda IBAN/telefon şifresiz) kararları; O-5 App Check zorlaması (yayından birkaç hafta sonra); O-6 Play Uygulama İmzalama doğrulaması ve imza şifresinin gücü; D-5 Firebase API anahtarı kısıtlaması | Sohbet / Tuncay |
| 2 | Code: üretime ilk çıkan sürüm için sürüm etiketi (ör. `v1.0.196`); üretimden önce de kapalı testteki güncel sürüm etiketlenebilir | Code |
| 3 | Üretim başvurusu (~1 Aralık): başvuru cevapları, mağaza metinleri, ekran görüntüleri | Sohbet + Tuncay |
| 4 | Satış ve iade sayfasındaki boş alanlar ile vergi durumu (mali müşavir) | Tuncay |
| 5 | Depoyu gizliye (private) almak, main için dal koruması, Dependabot uyarılarını açmak | Tuncay |
| 6 | Banner için uzaktan açma/kapama ve %50 kontrol grubu (Banner Kararları ortak şart 8) | Code |
| 7 | Yazı tiplerini lisanslarıyla depoya paketlemek; şu an CI'da indiriliyor (Görsel Kimlik kuralı 1) | Code |
| 8 | README'deki "4 dil" bilgisini 7 dile güncellemek | Code |
| 9 | 8 dil Aşama 2: Rusça | Sohbet → Code |
| 10 | Sonraya bırakılanlar: Yanıtlarım panosu, anı defteri, karekodla giriş, iki dilli bağlantı (bkz. `docs/backlog.md`) | Sohbet karar verir |

**Hatırlatmalar:** Google Cloud deneme kredisi 13 Şubat 2027'de bitiyor (bitişten 15 gün önce, sonra tam hesaba geçene kadar her gün hatırlatılacak).

## Değişiklik günlüğü

| Tarih | Kim | Ne |
|---|---|---|
| 28 Kasım 2026 | Code | Güvenlik denetimi Aşama 2: iş akışlarında salt okuma yetkisi, production kademeli yayın (%5/10/20, ilk çıkış istisnası), sunucu paketleri ve package-lock sabit, pubspec.lock + Flutter 3.50.1 sabit (CI kilit zorlar), yardımcı dallarda (crashcheck, storeshots) dış eylemler kesin sürümde, önizleme WebView'inde data: engeli |
| 28 Kasım 2026 | Code | Güvenlik denetimi Aşama 1 raporu; bu dosyada `docs/kurulum` satırı düzeltildi (dal PR #1 ile birleşmişti) |
| 28 Kasım 2026 | Sohbet | CLAUDE.md (ortak kurallar + Zarfla kalıcı kararları) ve bu durum dosyası eklendi |
| 28 Kasım 2026 | Code | Uzun adlar kart dışına taşmıyor, ad alanı en çok 24 karakter; 1.0.196 derlendi ve Play'e yüklendi |
| 25 Kasım 2026 | Code | Büyük sistem yazı boyutunda düzen ve Arapça satır yüksekliği düzeltmeleri |
| 22 Kasım 2026 | Code | İspanyolca, Portekizce, Endonezce eklendi; euro fiyatları eşitlendi; test reklamı bayrağı; Kullanım Koşulları onay satırı |
| 21 Kasım 2026 | Code | Güvenlik düzeltmeleri (davetli sayfası XSS, CSP, Storage kuralları), App Check izleme kipi |
| 17 Kasım 2026 | Code | Düğün Zinciri paketi, davetli sayfası Firebase Hosting'e, hatırlatma bildirimleri, gerçek AdMob, Dalga 3 tasarımlar |
