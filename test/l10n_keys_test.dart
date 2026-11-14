import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';

void main() {
  test('4 dilin ARB anahtarları aynı ve boş metin yok', () {
    final maps = {
      for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
    };
    final base = maps['tr']!.keys.toSet();
    expect(base.length, greaterThan(100));
    for (final l in kLangs) {
      expect(maps[l]!.keys.toSet(), base, reason: '$l anahtarları farklı');
      for (final e in maps[l]!.entries) {
        expect(e.value.trim(), isNotEmpty, reason: '$l.${e.key} boş');
      }
    }
    // Kodda kullanılan dinamik anahtarlar
    for (final ty in kEventTypes) {
      expect(base, contains('type_$ty'));
      expect(base, contains('eyebrow_$ty'));
    }
    for (final k in kLayouts) {
      expect(base, contains('lay_$k'));
    }
    for (final k in kOpenings) {
      expect(base, contains('opn_$k'));
    }
  });

  test('yer tutucu değişimi', () {
    final s = AppStrings({
      'tr': {'x': 'Kalan: {n}'},
    });
    expect(s.get('tr', 'x', {'n': 2}), 'Kalan: 2');
    expect(s.get('en', 'x'), 'Kalan: {n}'); // tr'ye düşer
  });
}
