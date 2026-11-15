import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';

// Not: Bu dosya, CI'daki `flutter create` komutunun varsayılan örnek testi
// üretmesini de engeller.
void main() {
  const newTypes = ['nikah', 'asker', 'mevlit', 'mezuniyet', 'evacilisi', 'iftar', 'disbugdayi', 'cinsiyet', 'yildonumu', 'bekarliga', 'kurumsal'];
  const singleNewTypes = ['asker', 'mevlit', 'mezuniyet', 'evacilisi', 'iftar', 'disbugdayi', 'bekarliga', 'kurumsal'];
  const colorKeys = ['bg', 'paper', 'ink', 'muted', 'accent', 'onAccent', 'gold', 'line', 'ring', 'err', 'door1', 'door2', 'doorLine', 'leaf'];

  test('katalog: 43 tasarım, tek ücretsiz (Papatya), REC her türde tüm tasarımları içerir', () {
    expect(kThemes.length, 43);
    expect(kThemes.values.where((t) => !t.premium).map((t) => t.id).toList(), ['papatya']);
    expect(kEventTypes.length, 19);
    for (final ty in kEventTypes) {
      expect(kRecommended[ty]!.toSet(), kThemes.keys.toSet(), reason: ty);
      expect(kRecommended[ty]!.length, kThemes.length, reason: '$ty: yinelenen tasarım');
      // Dalga 1 tasarımları öne eklendiği için ücretsiz Papatya en geç 9. sırada kalır (nisan/dugun: 8. indeks).
      expect(kRecommended[ty]!.take(9), contains('papatya'), reason: '$ty: papatya ilk 9 içinde olmalı');
      for (final l in kLangs) {
        expect(kMessages[l]![ty], isNotEmpty, reason: '$l/$ty');
      }
    }
  });

  test('dalga 1: 10 yeni tasarım, 12 açılış, hazır notlar (4 dilde 6 öneri), tür simgeleri', () {
    const wave1 = ['fener', 'siyahbeyaz', 'limon', 'pampas', 'nar', 'safak', 'avize', 'sadu', 'kelebek', 'bugday'];
    for (final id in wave1) {
      expect(kThemes[id], isNotNull, reason: id);
      expect(kThemes[id]!.premium, isTrue, reason: id);
    }
    expect(kOpenings, ['door', 'env', 'perde', 'kitap', 'muhur', 'isik', 'sarmasik', 'cicek', 'kurdele', 'kelebek', 'yildiz', 'pencere']);
    for (final l in kLangs) {
      expect(kNoteSuggestions[l]!.length, 6, reason: l);
      for (final m in kNoteSuggestions[l]!) {
        expect(m.trim(), isNotEmpty);
        expect(m.length, lessThanOrEqualTo(kNoteLen), reason: '$l: $m');
      }
    }
    expect(kTypeIcon['asker'], 'o-safak');
    expect(kTypeIcon['iftar'], 'o-fener');
    expect(kTypeIcon['disbugdayi'], 'o-bugday');
    expect(kTypeIcon['cinsiyet'], 'o-kelebek');
  });

  test('etkinlik türleri: sıra (mevcut 8 → yeni 11, "diger" en sonda), çift/tek isim, simgeler', () {
    expect(kEventTypes.take(7).toList(), ['nisan', 'dugun', 'kina', 'soz', 'sunnet', 'dogum', 'baby']);
    expect(kEventTypes.sublist(7, 18), newTypes);
    expect(kEventTypes.last, 'diger');
    expect(kEventTypes.toSet().length, 19);
    expect(kCoupleTypes, {'nisan', 'dugun', 'kina', 'soz', 'nikah', 'cinsiyet', 'yildonumu'});
    for (final ty in kEventTypes) {
      final icon = kTypeIcon[ty];
      expect(icon, isNotNull, reason: '$ty simgesi');
      expect(File('assets/ornaments/$icon.svg').existsSync(), isTrue, reason: '$ty simgesi dosyası: $icon');
    }
  });

  test('her tasarımda tüm renk alanları, 4 dilde ad ve süs dosyaları var', () {
    for (final th in kThemes.values) {
      expect(th.css.keys.toSet(), colorKeys.toSet(), reason: th.id);
      for (final l in kLangs) {
        expect((th.name[l] ?? '').trim(), isNotEmpty, reason: '${th.id}/$l');
      }
      for (final o in [th.orn, th.fall]) {
        expect(File('assets/ornaments/$o.svg').existsSync(), isTrue, reason: '${th.id}: assets/ornaments/$o.svg yok');
      }
    }
  });

  test('invite.html: her tasarım için orn/fall sembol kimliği tanımlı; tür verileri tam', () {
    final html = File('assets/invite/invite.html').readAsStringSync();
    final symbols = RegExp('<symbol id="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toList();
    expect(symbols.toSet().length, symbols.length, reason: 'yinelenen sembol kimliği');
    final ids = RegExp(r'\bid="([^"]+)"').allMatches(html).map((m) => m.group(1)!).toList();
    final seen = <String>{};
    final dup = ids.where((i) => !seen.add(i) && i != 'root').toList();
    expect(dup, isEmpty, reason: 'yinelenen id: $dup');
    for (final th in kThemes.values) {
      expect(symbols, contains(th.orn), reason: '${th.id}: orn ${th.orn} tanımsız');
      expect(symbols, contains(th.fall), reason: '${th.id}: fall ${th.fall} tanımsız');
      expect(html.contains('"${th.id}":{"name"'), isTrue, reason: '${th.id} THEMES içinde yok');
    }
    // url(#...) başvuruları çözülüyor
    for (final m in RegExp(r'url\(#([A-Za-z0-9_-]+)\)').allMatches(html)) {
      expect(ids, contains(m.group(1)), reason: 'çözülmeyen url(#${m.group(1)})');
    }
    final eyebrow = RegExp(r'const EYEBROW=(\{.*\});').firstMatch(html)!.group(1)!;
    final couple = RegExp(r'const COUPLE=(\{.*\});').firstMatch(html)!.group(1)!;
    for (final l in kLangs) {
      final block = RegExp('"$l":\\{([^}]*)\\}').firstMatch(eyebrow)!.group(1)!;
      for (final ty in kEventTypes) {
        expect(block.contains('"$ty":"'), isTrue, reason: 'EYEBROW.$l.$ty yok');
      }
    }
    for (final ty in kEventTypes) {
      expect(couple.contains('"$ty":1'), kCoupleTypes.contains(ty), reason: 'COUPLE.$ty');
    }
  });

  test('ARB: her yeni türde 4 dilde ad/eyebrow; tek isimli yeni türlerde isim etiketi', () {
    final maps = {for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync())};
    for (final l in kLangs) {
      for (final ty in newTypes) {
        expect((maps[l]!['type_$ty'] ?? '').trim(), isNotEmpty, reason: '$l type_$ty');
        expect((maps[l]!['eyebrow_$ty'] ?? '').trim(), isNotEmpty, reason: '$l eyebrow_$ty');
      }
      for (final ty in singleNewTypes) {
        expect((maps[l]!['nameLabel_$ty'] ?? '').trim(), isNotEmpty, reason: '$l nameLabel_$ty');
      }
      for (final ty in kCoupleTypes) {
        expect(maps[l]!.containsKey('nameLabel_$ty'), isFalse, reason: 'çift türde tek isim etiketi olmamalı: $ty');
      }
    }
  });

  test('AppStrings.has: tanımlı anahtar var, tanımsız yok', () {
    final s = AppStrings({
      'tr': {'a': 'x'},
    });
    expect(s.has('en', 'a'), isTrue);
    expect(s.has('tr', 'b'), isFalse);
  });
}
