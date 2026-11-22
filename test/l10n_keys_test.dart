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

  test('tüm dillerin ARB anahtarları aynı ve boş metin yok', () {
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
  // flt_modern: "Modern" tr/en/de'de aynı sözcük. lay_hikaye: "Story" en/de'de aynı (onaylı önizleme).
  const sameAllowed = {'app', 'premiumOn', 'lay_monogram', 'type_baby', 'amp', 'shareHead', 'shareWhen', 'flt_modern', 'lay_hikaye', 'versionLbl', 'errLogDetails'};

  test('hiçbir değer başka dilin metniyle aynı değil (istisnalar hariç)', () {
    final maps = {
      for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
    };
    // Özgün dört dil (tr/en/de/ar) arasında hiçbir çift aynı olamaz.
    const core = ['tr', 'en', 'de', 'ar'];
    for (final k in maps['tr']!.keys) {
      if (sameAllowed.contains(k)) continue;
      for (var i = 0; i < core.length; i++) {
        for (var j = i + 1; j < core.length; j++) {
          expect(maps[core[i]]![k] == maps[core[j]]![k], isFalse, reason: '$k: ${core[i]} ve ${core[j]} aynı');
        }
      }
    }
    // Yeni diller (es/pt/id): ortak kökenli sözcükler (Publicar, Galería, Klasik, Design…) doğal olarak aynı kalabilir;
    // yine de çeviri yapılmadan kopyalanmış metni yakalamak için çift başına üst sınır konur.
    // İspanyolca–Portekizce kardeş diller olduğu için bu çiftte sınır daha yüksektir.
    final extra = [for (final l in kLangs) if (!core.contains(l)) l];
    for (final n in extra) {
      for (final other in kLangs) {
        if (other == n || (extra.contains(other) && other.compareTo(n) < 0)) continue;
        final cap = ((n == 'es' && other == 'pt') || (n == 'pt' && other == 'es')) ? 60 : 12;
        final same = [
          for (final k in maps['tr']!.keys)
            if (!sameAllowed.contains(k) && maps[n]![k] == maps[other]![k]) k
        ];
        expect(same.length, lessThanOrEqualTo(cap), reason: '$n ve $other çok fazla aynı metin: $same');
      }
    }
  });

  test('yer tutucu {x} kümesi tüm dillerde aynı', () {
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

  test('cayma hakkı onay metni (withdrawalConsent) tüm dillerde mevcut ve Google Play iadesini belirtir', () {
    for (final l in kLangs) {
      final m = AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync());
      expect(m['withdrawalConsent'], isNotNull, reason: '$l withdrawalConsent yok');
      expect(m['withdrawalConsent']!, contains('Google Play'), reason: '$l metni Google Play içermiyor');
    }
  });
}
