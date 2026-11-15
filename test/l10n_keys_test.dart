import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';

void main() {
  test('ARB dosyalarında tekrarlanan anahtar yok (birleştirmede ikiye katlanmasın)', () {
    for (final l in kLangs) {
      final keys = RegExp(r'^  "([^"]+)":', multiLine: true)
          .allMatches(File('assets/l10n/app_$l.arb').readAsStringSync())
          .map((m) => m.group(1)!)
          .toList();
      final seen = <String>{};
      final dups = keys.where((k) => !seen.add(k)).toList();
      expect(dups, isEmpty, reason: '$l tekrarlanan anahtarlar: $dups');
    }
  });

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

  // Marka adı / ortak sözcük olduğu için diller arasında aynı kalabilen anahtarlar (açık istisna listesi).
  // amp: "&" işareti; shareHead/shareWhen: yalnız yer tutucu + simgeden oluşan paylaşım kalıpları;
  // flt_modern: "Modern" tr/en/de'de aynı sözcük.
  const sameAllowed = {'app', 'premiumOn', 'lay_monogram', 'type_baby', 'amp', 'shareHead', 'shareWhen', 'flt_modern'};

  test('hiçbir değer başka dilin metniyle aynı değil (istisnalar hariç)', () {
    final maps = {
      for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
    };
    for (final k in maps['tr']!.keys) {
      if (sameAllowed.contains(k)) continue;
      for (var i = 0; i < kLangs.length; i++) {
        for (var j = i + 1; j < kLangs.length; j++) {
          expect(maps[kLangs[i]]![k] == maps[kLangs[j]]![k], isFalse, reason: '$k: ${kLangs[i]} ve ${kLangs[j]} aynı');
        }
      }
    }
  });

  test('yer tutucu {x} kümesi dört dilde aynı', () {
    final maps = {
      for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
    };
    Set<String> ph(String v) => RegExp(r'\{(\w+)\}').allMatches(v).map((m) => m.group(1)!).toSet();
    for (final k in maps['tr']!.keys) {
      for (final l in kLangs) {
        expect(ph(maps[l]![k]!), ph(maps['tr']![k]!), reason: '$l.$k yer tutucuları farklı');
      }
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
