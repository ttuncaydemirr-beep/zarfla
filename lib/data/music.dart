/// Davetiye arka plan müziği seçkisi — YALNIZ ücretli davetiyede çalar, kullanıcı ses yükleyemez.
///
/// Telif kaydı: docs/music_licenses.md. Aynı liste (aynı kimlikler) üç yerde tutulur ve
/// test/music_catalog_test.dart ile karşılaştırılır:
///   1) bu dosya (uygulama editörü)
///   2) assets/invite/invite.html → `const MUSIC` (davetli sayfası; künye metni orada)
///   3) stüdyo sitesi src/music/manifest.json (dosyaları üreten iş akışı)
/// Dosya adresi: https://zarfla-37da9.web.app/music/<id>.mp3 (kendi Firebase Hosting sitemiz, üçüncü taraf yok).
library;

import '../cloud/invite_contract.dart' show kGuestHostUrl;

const String kMusicBaseUrl = '$kGuestHostUrl/music/';

/// Editördeki sekmeler (ARB anahtarı: musicCat_<kategori>).
const List<String> kMusicCategories = ['dugun', 'kina', 'cocuk', 'klasik', 'ramazan', 'kutlama'];

class MusicTrack {
  const MusicTrack(this.id, this.category, this.title, this.artist, {this.ccBy = true});

  final String id;
  final String category;

  /// Eserin özgün adı (çevrilmez).
  final String title;

  /// Besteci / icracı (künye satırı, çevrilmez).
  final String artist;

  /// true: CC BY 4.0 — künye zorunlu. false: kamu malı kayıt.
  final bool ccBy;

  String get url => '$kMusicBaseUrl$id.mp3';

  /// Uygulamadaki listede gösterilen künye (CC BY parçalar için lisans adı dahil).
  String get credit => ccBy ? '$artist · CC BY 4.0' : artist;
}

const String _km = 'Kevin MacLeod (incompetech.com)';
const String _usmb = 'U.S. Marine Band';

const List<MusicTrack> kMusicTracks = [
  MusicTrack('dugun-wagner', 'dugun', 'Wagner Bridal Chorus', _km),
  MusicTrack('dugun-handel', 'dugun', 'Water Music: Alla hornpipe', 'Handel · $_usmb', ccBy: false),
  MusicTrack('dugun-mozart', 'dugun', 'Serenade No. 10: Romance', 'Mozart · $_usmb', ccBy: false),
  MusicTrack('kina-desert-city', 'kina', 'Desert City', _km),
  MusicTrack('nisan-heartwarming', 'kina', 'Heartwarming', _km),
  MusicTrack('cocuk-monkeys', 'cocuk', 'Monkeys Spinning Monkeys', _km),
  MusicTrack('cocuk-balloon', 'cocuk', 'Balloon Game', _km),
  MusicTrack('cocuk-pookatori', 'cocuk', 'Pookatori and Friends', _km),
  MusicTrack('klasik-grieg', 'klasik', 'Holberg Suite: Air', 'Grieg · $_usmb', ccBy: false),
  MusicTrack('klasik-bach', 'klasik', 'Prelude in C (BWV 846)', 'Bach · $_km'),
  MusicTrack('klasik-satie', 'klasik', 'Gymnopedie No. 2', 'Satie · $_km'),
  MusicTrack('ramazan-calmant', 'ramazan', 'Calmant', _km),
  MusicTrack('ramazan-clear-waters', 'ramazan', 'Clear Waters', _km),
  MusicTrack('kutlama-beachfront', 'kutlama', 'Beachfront Celebration', _km),
  MusicTrack('kutlama-funky', 'kutlama', 'Funky Chunk', _km),
  MusicTrack('kutlama-joplin', 'kutlama', 'The Entertainer', 'Joplin · $_km'),
];

MusicTrack? musicTrackById(String id) {
  for (final t in kMusicTracks) {
    if (t.id == id) return t;
  }
  return null;
}

/// Bilinen kimlik ise aynen, değilse '' (müzik yok).
String cleanMusicId(Object? v) => (v is String && musicTrackById(v) != null) ? v : '';

/// Editörde ilk açılan sekme: davetiye türüne en uygun kategori.
String musicCategoryForType(String type) {
  switch (type) {
    case 'dugun':
    case 'nikah':
    case 'yildonumu':
      return 'dugun';
    case 'kina':
    case 'nisan':
    case 'soz':
      return 'kina';
    case 'dogum':
    case 'baby':
    case 'sunnet':
    case 'disbugdayi':
    case 'cinsiyet':
      return 'cocuk';
    case 'mevlit':
    case 'iftar':
      return 'ramazan';
    case 'mezuniyet':
    case 'evacilisi':
    case 'bekarliga':
    case 'asker':
      return 'kutlama';
    default:
      return 'klasik';
  }
}
