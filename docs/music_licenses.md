# Zarfla — Davetiye müziği telif kaydı

Hazırlayan: ses/lisans sorumlusu (Zarfla ekibi) · Doğrulama tarihi: 15 Kasım 2026 · Sahip talimatı: "telif konusuna aşırı dikkat et".

## Kurallar (kısa)

- Davetiyede yalnızca **bu listedeki** parçalar çalar. Kullanıcı **asla** ses dosyası yükleyemez.
- Dosyalar **kendi barındırmamızdan** (Firebase Hosting, davetli sayfasıyla aynı köken) sunulur: `https://zarfla-37da9.web.app/music/<kimlik>.mp3`. Üçüncü taraf bağlantısı yok.
  `tools/build_hosting.py` dosyaları stüdyo sitesi deposundaki `src/music/`'ten **sha256 doğrulayarak** kopyalar (aynı lisanslı dosyalar; yeni parça eklenemez).
- Dosyaları yalnızca `ttuncaydemirr-beep.github.io` deposundaki `.github/workflows/fetch-music.yml` iş akışı üretir:
  aşağıdaki indirme adresinden alır, kaynak SHA-1'ini karşılaştırır (değişmişse **durur**), en çok 90 sn'ye kısaltır,
  2 sn açılış / 4 sn kapanış geçişi ve ses eşitlemesi (-20 LUFS) uygular, 96 kbps MP3 yazar, sha256'yı `src/music/manifest.json`'a kaydeder.
- Müzik **yalnız ücretli** (1 Davetiye Hakkı) davetiyede çalar; ücretsiz davetiyede seçici kilitli, Firestore kuralları da reddeder.
- CC BY parçalarında atıf (künye) **davetli sayfasının alt bilgisinde** ve **uygulamadaki müzik listesinde** gösterilir.
  Biçim: `Müzik: “<Ad>” – Kevin MacLeod (incompetech.com) · CC BY 4.0 · kısaltıldı` (dört dilde).
  CC BY 4.0 madde 3(a)(1)(B) "değişiklik yapıldıysa belirt" gereği "kısaltıldı" ibaresi eklenir.
- Yeni parça eklemek için: önce bu dosyaya kayıt (kaynak sayfa doğrulaması + alıntı), sonra manifest, sonra iş akışı.

## Kabul edilen lisans türleri

1. **Kamu malı (bestesi + kaydı)** — ABD Deniz Piyadeleri Bandosu ("The President's Own" U.S. Marine Band) kayıtları:
   ABD federal hükümeti çalışanlarının görev kapsamında ürettiği eserler ABD'de telif korumasına girmez; besteciler 100+ yıl önce öldü.
   Commons sayfalarında besteye ve icra/kayda **ayrı ayrı** kamu malı şablonu var (aşağıda alıntılı).
2. **CC BY 4.0** — Kevin MacLeod (incompetech.com). Ticari kullanım, uygulama/web ürününde yeniden dağıtım ve
   kısaltma (uyarlama) serbesttir; tek şart görünür atıf ve değişikliğin belirtilmesi. Lisans geri alınamaz.
   Lisans dayanağı: incompetech SSS ve her parçanın incompetech sayfasındaki "Attribution Code".

> incompetech SSS (https://incompetech.com/music/royalty-free/faq.html): "Licensed under Creative Commons: By Attribution 4.0"
> Atıf şablonu (aynı sayfa): `Title Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / https://creativecommons.org/licenses/by/4.0/`
> Lisans metni: https://creativecommons.org/licenses/by/4.0/legalcode.en

Not: Commons'taki `(ISRC …).mp3` kopyaları Commons sayfasında **CC BY 3.0** etiketli (yükleme tarihindeki lisans). Lisans veren
(Kevin MacLeod) aynı eserleri bugün incompetech'te **CC BY 4.0** ile sunduğu için 4.0'a dayanıyoruz; 3.0 da tek başına yeterlidir
(ticari kullanım + atıf). Dosyanın baytları Commons'tan alınır çünkü Commons SHA-1 verir (bütünlük denetimi).

## Parça listesi (16 parça)

| Kategori | Kabul edilen |
|---|---|
| Düğün / Nikah | 3 |
| Kına / Nişan | 2 |
| Çocuk (doğum günü, baby shower, sünnet) | 3 |
| Klasik | 3 |
| Ramazan / Mevlit-iftar | 2 |
| Kutlama | 3 |

Süre sütunu kaynak dosyanın süresidir; yayımlanan dosya en çok 90 sn'dir.

### Düğün / Nikah

**1. `dugun-wagner` — Wagner Bridal Chorus**
- Besteci: Richard Wagner (1813–1883) · Düzenleme/icra: Kevin MacLeod
- Kaynak sayfa: https://commons.wikimedia.org/wiki/File:Wagner_Bridal_Chorus_(ISRC_USUAN1100021).mp3
- Lisans: CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/ (dayanak: https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100021 ; Commons kopyası: CC BY 3.0)
- Atıf şartı (incompetech): `"Wagner Bridal Chorus" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 2:19 · Kaynak SHA-1: 0730a9c2da57a5ddbef66e670334764f49ee96b1
- Neden uygun: Lohengrin'den gelin marşı; nikâhın en bilinen girişi. Beste kamu malı, düzenleme MacLeod'un kendi eseri.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/a/a3/Wagner_Bridal_Chorus_%28ISRC_USUAN1100021%29.mp3

**2. `dugun-handel` — Water Music: Alla hornpipe (HWV 349)**
- Besteci: George Frideric Handel (1685–1759) · İcra: U.S. Marine Band, Marine Chamber Orchestra (29 Ocak 2017, şef Maj. Michelle Rakers)
- Kaynak sayfa: https://commons.wikimedia.org/wiki/File:Handel%27s_Water_Music_-_12._Alla_hornpipe_-_Chamber_Orchestra_-_United_States_Marine_Band.opus
- Lisans: Kamu malı. Beste: "The author died in 1759, so this work is in the public domain…"; icra/kayıt (PD-USGov-Military-Marines):
  "This file is a work of a United States Marine or employee, taken or made as part of that person's official duties. As a work of the U.S. federal government, it is in the public domain."
- Atıf şartı: yok (kibarlık gereği künye manifestte tutulur, sayfada gösterilmez)
- Süre: 3:49 · Kaynak SHA-1: 2d485a41b7b13daee4b31451b9987f2f12cda30c
- Neden uygun: Törensel, neşeli bir giriş müziği; düğünlerde sık kullanılan barok parça. Özgün çalgılama (düzenleme telifi riski yok).
- İndirme: https://upload.wikimedia.org/wikipedia/commons/5/5c/Handel%27s_Water_Music_-_12._Alla_hornpipe_-_Chamber_Orchestra_-_United_States_Marine_Band.opus

**3. `dugun-mozart` — Serenade No. 10 "Gran Partita": V. Romance**
- Besteci: Wolfgang Amadeus Mozart (1756–1791) · İcra: "The President's Own" U.S. Marine Band (20 Mayıs 2021)
- Kaynak sayfa: https://commons.wikimedia.org/wiki/File:Mozart%27s_Serenade_No._10_%22Grand_Partita%22_-_V._Romance._Adagio_-_United_States_Marine_Band.mp3
- Lisans: Kamu malı (beste PD-old; "Performance and Recording": PD-USGov-Military-Marines, yukarıdaki alıntıyla aynı şablon)
- Atıf şartı: yok
- Süre: 7:08 · Kaynak SHA-1: 4c98a9f0e3e7e370d44bb8db5fb4e565d6943b34
- Neden uygun: Yavaş, zarif üflemeli serenat; romantik ve ağırbaşlı. Eser zaten üflemeliler için yazıldı (düzenleme yok).
- İndirme: https://upload.wikimedia.org/wikipedia/commons/a/ac/Mozart%27s_Serenade_No._10_%22Grand_Partita%22_-_V._Romance._Adagio_-_United_States_Marine_Band.mp3

### Kına / Nişan

**4. `kina-desert-city` — Desert City**
- Besteci/icra: Kevin MacLeod
- Kaynak sayfa: https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100564
- Lisans: CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
- Atıf şartı (sayfadaki kod): `"Desert City" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 1:29 · Kaynak SHA-1: — (Commons'ta yok; iş akışı sha256'yı ilk indirmede kaydeder)
- Neden uygun: incompetech açıklaması "Middle Eastern atmospheric, sort of chill"; santur benzeri telli çalgı + vurmalı. Yöresel his veren, telifli bir türkü kaydı içermeyen özgün beste.
- İndirme: https://incompetech.com/music/royalty-free/mp3-royaltyfree/Desert%20City.mp3

**5. `nisan-heartwarming` — Heartwarming**
- Besteci/icra: Kevin MacLeod
- Kaynak sayfa: https://commons.wikimedia.org/wiki/File:Heartwarming_(ISRC_USUAN1100207).mp3 (incompetech: ?isrc=USUAN1100207)
- Lisans: CC BY 4.0 (Commons kopyası CC BY 3.0)
- Atıf şartı: `"Heartwarming" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 1:12 · Kaynak SHA-1: 6214ff95935a63ae41665c83acec3b70adba3334
- Neden uygun: Sıcak, parlak piyano ("warm and bright… tender interlude"); nişan için samimi.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/2/26/Heartwarming_%28ISRC_USUAN1100207%29.mp3

### Çocuk (doğum günü, baby shower, sünnet)

**6. `cocuk-monkeys` — Monkeys Spinning Monkeys**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Monkeys_Spinning_Monkeys_(ISRC_USUAN1400011).mp3 (incompetech ?isrc=USUAN1400011)
- Lisans: CC BY 4.0 · Atıf: `"Monkeys Spinning Monkeys" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 2:05 · SHA-1: 6937f8d7b10b2a6c695f525d6a6fabe8aad1634d
- Neden: "Loopable happy light fluffy piece"; flüt + pizzicato, oyuncu ve döngüye uygun.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/e/e9/Monkeys_Spinning_Monkeys_%28ISRC_USUAN1400011%29.mp3

**7. `cocuk-balloon` — Balloon Game**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Balloon_Game_(ISRC_USUAN1700063).mp3 (incompetech ?isrc=USUAN1700063)
- Lisans: CC BY 4.0 · Atıf: `"Balloon Game" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 3:42 · SHA-1: bedc0c461c5b7a37cf17c6a818263dc4922cb622
- Neden: "Bouncy, Bright"; balonlu doğum günü teması.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/2/27/Balloon_Game_%28ISRC_USUAN1700063%29.mp3

**8. `cocuk-pookatori` — Pookatori and Friends**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Pookatori_and_Friends_(ISRC_USUAN1700002).mp3 (incompetech ?isrc=USUAN1700002)
- Lisans: CC BY 4.0 · Atıf: `"Pookatori and Friends" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 4:08 · SHA-1: edcbdd689ffc726da714505a1cee2d6583b65e3b
- Neden: "Bright, Bouncy, Grooving"; sözsüz, neşeli elektronik.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/0/0e/Pookatori_and_Friends_%28ISRC_USUAN1700002%29.mp3

### Klasik (kamu malı besteler)

**9. `klasik-grieg` — Holberg Suite, Op. 40: IV. Air**
- Besteci: Edvard Grieg (1843–1907) · İcra: U.S. Marine Band, Marine Chamber Orchestra (17 Ağustos 2013, şef Maj. Jason K. Fettig)
- Kaynak: https://commons.wikimedia.org/wiki/File:Grieg%27s_Suite_for_Strings,_Op._40,_%22From_Holberg%E2%80%99s_Time%22_-_IV._Air_-_Chamber_Orchestra_-_United_States_Marine_Band.mp3
- Lisans: Kamu malı (beste: "The author died in 1907…"; icra ve kayıt: PD-USGov-Military-Marines) · Atıf şartı: yok
- Süre: 5:17 · SHA-1: fc873f0bb14db2aa6fcf96ee4981f5270d23b161
- Neden: Yaylılar için özgün eser, duygulu ve zarif.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/2/28/Grieg%27s_Suite_for_Strings%2C_Op._40%2C_%22From_Holberg%E2%80%99s_Time%22_-_IV._Air_-_Chamber_Orchestra_-_United_States_Marine_Band.mp3

**10. `klasik-bach` — Prelude in C (BWV 846)**
- Besteci: J. S. Bach (1685–1750) · İcra: Kevin MacLeod
- Kaynak: https://commons.wikimedia.org/wiki/File:Prelude_in_C_(BWV_846)_(ISRC_USUAN1100689).mp3 (incompetech ?isrc=USUAN1100689)
- Lisans: CC BY 4.0 (kayıt) · beste kamu malı · Atıf: `"Prelude in C - BWV 846" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 2:58 · SHA-1: f256a2365ad44a4692d52c3f6e8d939ad10eb686
- İndirme: https://upload.wikimedia.org/wikipedia/commons/a/ac/Prelude_in_C_%28BWV_846%29_%28ISRC_USUAN1100689%29.mp3

**11. `klasik-satie` — Gymnopédie No. 2**
- Besteci: Erik Satie (1866–1925; ölümünden bu yana 70+ yıl, ABD'de 1895 yayını) · Düzenleme/icra: Kevin MacLeod
- Kaynak: https://commons.wikimedia.org/wiki/File:Gymnopedie_No._2_(ISRC_USUAN1100786).mp3 (incompetech ?isrc=USUAN1100786)
- Lisans: CC BY 4.0 (kayıt) · Atıf: `"Gymnopedie No 2" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 2:39 · SHA-1: 2ad7ff5a728cc7a935dd90c3177b12c5eae4784e
- İndirme: https://upload.wikimedia.org/wikipedia/commons/2/20/Gymnopedie_No._2_%28ISRC_USUAN1100786%29.mp3

### Ramazan / Mevlit-iftar (sakin, saygılı, sözsüz — dinî okuma/ses yok)

**12. `ramazan-calmant` — Calmant**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Calmant_(ISRC_USUAN1100859).mp3 (incompetech ?isrc=USUAN1100859)
- Lisans: CC BY 4.0 · Atıf: `"Calmant" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 3:24 · SHA-1: f01c240011042a3a8b173901678589977705242d
- Neden: Yalnız piyano, "Slow moving, semi-arpeggio theme"; sakin, ağırbaşlı. Herhangi bir dinin ilahisi/okuması değil.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/f/fa/Calmant_%28ISRC_USUAN1100859%29.mp3

**13. `ramazan-clear-waters` — Clear Waters**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Clear_Waters_(ISRC_USUAN1100290).mp3 (incompetech ?isrc=USUAN1100290)
- Lisans: CC BY 4.0 · Atıf: `"Clear Waters" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 2:08 · SHA-1: 62a4187b6f7924f94bf05f894003ae764e68b043
- Neden: Yalnız piyano, "Calming, Relaxed".
- İndirme: https://upload.wikimedia.org/wikipedia/commons/a/ae/Clear_Waters_%28ISRC_USUAN1100290%29.mp3

### Kutlama

**14. `kutlama-beachfront` — Beachfront Celebration**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Beachfront_Celebration_(ISRC_USUAN1200022).mp3 (incompetech ?isrc=USUAN1200022)
- Lisans: CC BY 4.0 · Atıf: `"Beachfront Celebration" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 3:07 · SHA-1: 63691de89ff27515913dbab10444546c5c48c636
- Neden: "Bouncy, Bright, Grooving, Uplifting"; parti havası.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/a/a8/Beachfront_Celebration_%28ISRC_USUAN1200022%29.mp3

**15. `kutlama-funky` — Funky Chunk**
- Kevin MacLeod · Kaynak: https://commons.wikimedia.org/wiki/File:Funky_Chunk_(ISRC_USUAN1500054).mp3 (incompetech ?isrc=USUAN1500054)
- Lisans: CC BY 4.0 · Atıf: `"Funky Chunk" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 3:59 · SHA-1: 46bdd310ec9b6537b9555398f9394c4aa0428464
- Neden: "Bright, Grooving, Uplifting"; temiz funk, mezuniyet/yeni ev/yıl dönümü.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/a/a2/Funky_Chunk_%28ISRC_USUAN1500054%29.mp3

**16. `kutlama-joplin` — The Entertainer**
- Besteci: Scott Joplin (1868–1917) · Düzenleme/icra: Kevin MacLeod
- Kaynak: https://commons.wikimedia.org/wiki/File:The_Entertainer_by_Kevin_MacLeod.ogg (Commons'ta CC BY 4.0; kaynak incompetech.filmmusic.io)
- Lisans: CC BY 4.0 · Atıf: `"The Entertainer" Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 License`
- Süre: 3:13 · SHA-1: 45111a083a1d5ea88142e4813a6727320cca5d4f
- Neden: Herkesin tanıdığı neşeli ragtime; beste kamu malı.
- İndirme: https://upload.wikimedia.org/wikipedia/commons/6/6b/The_Entertainer_by_Kevin_MacLeod.ogg

## Reddedilen kaynaklar / parçalar

| Aday | Neden reddedildi |
|---|---|
| Pixabay | Pixabay Lisansı "does not allow: … Sale or distribution of Content e.g. as … music files … without adding any additional elements or otherwise adding value" (alıntı: lisansın ScanCode arşiv kopyası, https://scancode-licensedb.aboutcode.org/pixabay-content.html — güncel sayfa bu ortamdan açılamadı). Müzik dosyasını kullanıcı davetiyelerinde sunmamızın "değer katma" sayılıp sayılmayacağı belirsiz; ayrıca Pixabay müziklerinde Content ID kaydı yaygın → ret. |
| Uppbeat, YouTube Ses Kitaplığı, Mixkit | Lisans metinleri bu çalışmada okunup alıntılanamadı; kuralımız gereği uygulama/şablon içinde son kullanıcıya yeniden dağıtıma **açıkça** izin verdiği görülmeyen kaynak kullanılmaz → değerlendirme dışı bırakıldı (ret). |
| freepd.com (CC0) | Lisansı uygun olabilir ama sayfa bu ortamdan doğrulanamadı (erişim yok); doğrulanamayan kaynak kullanılmaz. |
| Free Music Archive (ör. Loyalty Freak Music, CC0) | Lisans CC0 doğrulandı ancak dosya indirme oturum açma gerektiriyor; iş akışı güvenilir şekilde indiremez ve bütünlük (SHA) doğrulanamaz. İleride ayrıca değerlendirilebilir. |
| "A Midsummer Night's Dream – Wedding March (Mendelssohn) European Archive" (Commons, "Public domain") | Eski plak kaydı; kamu malı oluşu AB'deki eski 50 yıl kuralına dayanıyor, ABD'de (1972 öncesi kayıtlar) ve diğer ülkelerde hâlâ korunuyor olabilir. Kaynak belirsiz → ret. |
| "An der schönen, blauen Donau" – U.S. Marine Band (1972) | Kayıt kamu malı, fakat "arr. for wind ensemble" — düzenleyici belirsiz; özel bir düzenlemenin telifi sürüyor olabilir → ret. |
| Kevin MacLeod – "Love Song" | Lisans uygun ama incompetech'te "Gloom and Sadness", "Somber, Eerie" olarak etiketli; düğüne uygun değil. |
| Kevin MacLeod – "Children's Theme" | Adına rağmen tür "Horror"; çocuk davetiyesine uygun değil. |
| Kevin MacLeod – "Babylon", "Old Road", "Jalandhar" | Lisans uygun ama "Dark/Mysterious/Suspenseful" ruh hali; kınaya uygun değil. |
| Kevin MacLeod – "Finding the Balance" | Yabancı dilde kadın vokali içeriyor (sözlü) → kına/nişan için risk. |
| "Kol Nidrei" – U.S. Marine Band | Kamu malı ama Yahudi dinî metnine dayanan eser; Ramazan/Mevlit için uygunsuz. |
| Commons "Wedding March … Player Piano" (CC BY-SA 4.0) | SA (ShareAlike) → kural gereği kaçınıldı. |
| Vivaldi vb. CC BY-SA kayıtlar (Commons) | SA → ret. |
| Telifli türkü / halk müziği kayıtları | Bestesi anonim olsa da kayıt ve düzenleme telifli → hiç aranmadı. |

## Riskler ve notlar

1. **Content ID**: Kevin MacLeod parçaları zaman zaman üçüncü kişilerce YouTube'da haksız yere sahiplenilebiliyor. Bizim kullanımımız
   (kendi sitemiz) YouTube değildir; ancak davetiyenin ekran kaydı YouTube'a konursa uyarı çıkabilir. Kanıt: bu dosya + CC BY 4.0.
2. **ABD hükümeti eserleri** ABD'de kamu malıdır; teorik olarak ABD dışında telif iddia edilebilir (uygulamada bilinen bir örnek yok).
   Commons bu kayıtları kamu malı olarak barındırır.
3. **iOS Safari** ses düzeyini (volume) yazılımla değiştirmeye izin vermez; bu yüzden dosyalar zaten -20 LUFS'a eşitlenir (kısık başlar).
4. Kaynak dosya değişirse (SHA-1 uyuşmazsa) iş akışı durur; parça yeniden doğrulanmadan yayımlanmaz.
5. Desert City için Commons kopyası olmadığından ilk indirmede yalnız sha256 kaydedilir (kaynak bütünlüğü sonraki çalıştırmalarda bununla izlenir).
