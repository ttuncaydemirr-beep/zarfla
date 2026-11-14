import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';

// Not: Bu dosya, CI'daki `flutter create` komutunun varsayılan örnek testi
// üretmesini de engeller.
void main() {
  test('katalog: 17 tasarım, tek ücretsiz (Papatya), REC her türde tüm tasarımları içerir', () {
    expect(kThemes.length, 17);
    expect(kThemes.values.where((t) => !t.premium).map((t) => t.id).toList(), ['papatya']);
    for (final ty in kEventTypes) {
      expect(kRecommended[ty]!.toSet(), kThemes.keys.toSet(), reason: ty);
      for (final l in kLangs) {
        expect(kMessages[l]![ty], isNotEmpty, reason: '$l/$ty');
      }
    }
  });
}
