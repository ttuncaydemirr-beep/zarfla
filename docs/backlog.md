# Zarfla — Sonraya bırakılan işler (sahibin kararı, 15 Kasım 2026)

- **Anı defteri (dilek defteri):** Davetliler davetiye sayfasına kısa tebrik mesajı bırakır; davet sahibi uygulamada görür/siler. Gerekenler: mesaj saklama, silme/şikâyet (moderasyon), gizlilik metni ve Play veri güvenliği formu güncellemesi. Karar: sonra yapılabilir.
- **Karekodla giriş:** Davetliye özel QR, salon girişinde okutup "kimler geldi" listesi. Önce davetli listesi sistemi gerekir. Karar: sonra yapılabilir.

## UX incelemesinden kalanlar (15 Kasım 2026, `staging/ux/ux_review.md` bölüm 4)

Kural: sunucuda yeni davetli verisi toplamayan fikirler bu dalda (`ux-fixes`) yapıldı; veri toplayan ya da yeni
izin/eklenti/ürün kararı gerektirenler aşağıda tasarım notu olarak bekliyor.

### 1. "Yanıtlarım" panosu (RSVP sayımı) — davetli verisi saklar
- **Ne:** Davetli formu WhatsApp'a gitmeden önce yanıtı sunucuya da yazar; uygulamada "12 geliyor · 3 gelemiyor · 8 bekleniyor"
  ve "Hatırlat" (hazır WhatsApp mesajı). Ücretsizde yalnız toplam sayı, ücretlide isim listesi + hatırlatma (yükseltme gerekçesi).
- **Veri:** `invites/{id}/rsvps/{auto}`: `{name ≤60, att: yes|no, count 1–10, msg ≤300, createdAt}`. Kişisel veri (ad, mesaj) →
  gizlilik politikası (/privacy/zarfla/) ve Play "Veri güvenliği" formu güncellenmeli; davet silinince alt koleksiyon da silinir
  (`cleanupStorage` benzeri zamanlanmış temizlik + davet sahibinin silmesinde toplu silme).
- **Kurallar:** `create` herkese açık ama yalnız belge `live` ve süresi dolmamışken; alan/uzunluk denetimi; `read/list` yalnız
  `ownerUid`. Kötüye kullanım: App Check (Play Integrity) + davet başına üst sınır (ör. 500) — kurallar sayamadığı için
  `onDocumentCreated` tetikleyicisiyle sayaç (`rsvpCount`) ve sınır aşımında silme. Kural testleri `rules-test/` altına.
- **Davetli sayfası:** gönderimde önce `fetch` (Firestore REST, anahtarsız `createDocument`), başarısız olsa da WhatsApp akışı
  bugünkü gibi sürer (yanıt kaybolmasın). CSP `connect-src` zaten firestore.googleapis.com.
- **Uygulama:** editörde/ana ekranda sayaç kartı; ücretlide liste ekranı. Tahmini efor: L (kurallar + tetikleyici + iki ekran).

### 2. Bildirimler (süre bitiyor / yarım taslak) — yeni izin ve eklenti
- **Ne:** (a) Ücretsiz bağlantı kapanmadan 3 saat önce "Davetiyenizin bağlantısı 3 saat sonra kapanıyor — süreyi uzatın";
  (b) taslak 24 saat düzenlenmezse "Elif & Can davetiyeniz yarım kaldı (%75 hazır)".
- **Yol:** sunucu gerekmez — `flutter_local_notifications` ile cihazda zamanlanmış bildirim (Android 13+ bildirim izni,
  Android 12+ kesin alarm yerine yaklaşık zamanlama yeterli). Metinler ARB'ye (4 dil). Yayında/taslakta kaydetmede yeniden zamanla,
  silmede iptal et. Play politikası: pazarlama değil, kullanıcının kendi işine dair hatırlatma; ayarlarda kapatılabilir olmalı.
- **Neden bekliyor:** yeni eklenti + izin akışı + Play beyanı; ürün sahibinin onayı gerekir. Efor: M.

### 3. Ücretsiz bağlantı süresi 1 gün → 3 gün (A/B)
- Ürün/gelir kararı; değişirse `kFreeLife` (lib/cloud/invite_contract.dart), firestore.rules `1450m` sınırı, `freeL1` metni ve
  `functions` testleri birlikte güncellenir. Önce Firebase Remote Config yerine iki sürümlü dağıtımla ölçüm önerilir.

### 4. Tek bağlantı, iki dil (fikir 5)
- **Ne:** Davet sahibi isteğe bağlı "ikinci dil" seçer (ör. TR + DE); davetli sayfasında üstte dil düğmesi etiketleri (Ne zaman,
  Nerede, Katılım, tarih biçimi) değiştirir. Davet sahibinin yazdığı metin tek kalır (ya da ikinci metin alanı).
- **Gerekenler:** veri sözleşmesine `lang2` anahtarı (invite_contract.dart anahtar sırası + testi), invite.html'de dil düğmesi,
  editörde seçim, paylaşım metninin iki dilde hazırlanması (Bitti ekranı). Ücretli pakete özelse kurallarda/`ruleDataOk`'ta
  IBAN/müzik gibi "yalnız paid" denetimi + kural testleri.
- **Neden bekliyor:** sunucu verisi toplamaz ama veri sözleşmesi + kurallar + stüdyo sitesindeki davetli motoru birlikte değişir
  ve "ücretli mi, ücretsiz mi" ürün kararı gerekir. Efor: M–L.

### 5. "Önce isimler, sonra tasarım" (fikir 2)
- Tasarım galerisi/akış sırası diğer mühendisin kapsamında (bulgu #12 galeri kısmı); bu dalda yalnız varsayılan tasarım ücretsiz
  Papatya yapıldı ve editörde tasarımın fiyat rozeti gösterildi.
