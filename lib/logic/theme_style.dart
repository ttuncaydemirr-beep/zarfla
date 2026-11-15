import '../data/catalog.dart';

/// Galeri stil filtreleri (tasarım incelemesi 3.1). "Açık / Koyu" zemin parlaklığından hesaplanır;
/// diğer stiller elle sınıflandırılmıştır (bir tasarım birden çok stilde olabilir).
const List<String> kGalleryFilters = ['rec', 'all', 'free', 'light', 'dark', 'floral', 'classic', 'modern', 'kids'];

/// Önerilen görünümde türe göre ilk kaç tasarım gösterilir.
const int kRecommendedCount = 12;

const Map<String, Set<String>> kThemeStyles = {
  'floral': {
    'papatya', 'gul', 'okaliptus', 'lavanta', 'zeytin', 'adacayi', 'kurugul', 'sakayik', 'kadife', 'pampas', //
    'nar', 'kelebek', 'bugday', 'limon', 'kina',
  },
  'classic': {
    'kina', 'nazar', 'kemer', 'yildiz8', 'bordo', 'tezhip', 'cini', 'mevlit', 'fener', 'sadu', 'nar', 'avize',
  },
  'modern': {
    'altin', 'deco', 'monogram', 'siyahbeyaz', 'mehtap', 'orman', 'gunbatimi', 'safak', 'yeniev', 'mezuniyet', 'avize',
  },
  'kids': {
    'balon', 'bulut', 'ayicik', 'pembebulut', 'uzay', 'safari', 'denizalti', 'prens',
  },
};

/// Tasarım koyu zeminli mi (WCAG göreli parlaklık < 0.18).
bool isDarkTheme(InviteTheme t) => t.colors.bg.computeLuminance() < 0.18;

/// Filtreye uyan tasarımlar, türün öneri sırasıyla.
List<String> galleryThemes(String type, String filter) {
  final order = kRecommended[type] ?? kThemes.keys.toList();
  final ids = [for (final id in order) if (kThemes[id] != null) id];
  switch (filter) {
    case 'rec':
      final top = ids.take(kRecommendedCount).toList();
      // Ücretsiz Papatya önerilenlerde her zaman görünür.
      if (!top.contains('papatya') && ids.contains('papatya')) top.add('papatya');
      return top;
    case 'all':
      return ids;
    case 'free':
      return [for (final id in ids) if (!kThemes[id]!.premium) id];
    case 'light':
      return [for (final id in ids) if (!isDarkTheme(kThemes[id]!)) id];
    case 'dark':
      return [for (final id in ids) if (isDarkTheme(kThemes[id]!)) id];
    default:
      final set = kThemeStyles[filter] ?? const <String>{};
      return [for (final id in ids) if (set.contains(id)) id];
  }
}
