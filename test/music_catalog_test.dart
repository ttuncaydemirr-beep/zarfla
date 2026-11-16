import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/data/music.dart';
import 'package:zarfla/l10n/strings.dart';

/// Müzik seçkisi üç yerde aynı olmalı: lib/data/music.dart, assets/invite/invite.html (MUSIC),
/// stüdyo sitesi src/music/manifest.json (yan klasörde varsa). Telif kaydı: docs/music_licenses.md.
void main() {
  final html = File('assets/invite/invite.html').readAsStringSync();
  final a = html.indexOf('/*MUSIC-BEGIN*/');
  final b = html.indexOf('/*MUSIC-END*/');

  test('invite.html MUSIC bloğu uygulama kataloğuyla aynı (kimlik, ad, CC BY bayrağı, adres tabanı)', () {
    expect(a > 0 && b > a, isTrue, reason: 'MUSIC bloğu yok');
    final block = html.substring(a, b);
    final re = RegExp(r'^"([a-z0-9-]+)":\{t:"([^"]*)",by:([01])\}', multiLine: true);
    final js = {for (final m in re.allMatches(block)) m.group(1)!: (m.group(2)!, m.group(3) == '1')};
    expect(js.keys.toList(), kMusicTracks.map((t) => t.id).toList());
    for (final t in kMusicTracks) {
      expect(js[t.id]!.$1, t.title, reason: t.id);
      expect(js[t.id]!.$2, t.ccBy, reason: t.id);
    }
    expect(block.contains('const MUSIC_BASE="$kMusicBaseUrl"'), isTrue);
  });

  test('kimlik biçimi, kategoriler ve ARB sekme adları', () {
    final ids = <String>{};
    for (final t in kMusicTracks) {
      expect(RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(t.id), isTrue, reason: t.id);
      expect(ids.add(t.id), isTrue, reason: 'tekrar: ${t.id}');
      expect(kMusicCategories, contains(t.category));
      expect(t.url, '$kMusicBaseUrl${t.id}.mp3');
    }
    for (final c in kMusicCategories) {
      expect(kMusicTracks.where((t) => t.category == c), isNotEmpty, reason: 'boş kategori $c');
    }
    expect(kMusicTracks.length, inInclusiveRange(15, 20));
    for (final l in kLangs) {
      final m = AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync());
      for (final c in kMusicCategories) {
        expect(m.containsKey('musicCat_$c'), isTrue, reason: '$l musicCat_$c');
      }
      expect(m.containsKey('musicSoonApp'), isFalse, reason: 'eski yer tutucu kaldırılmalı');
    }
    for (final ty in kEventTypes) {
      expect(kMusicCategories, contains(musicCategoryForType(ty)));
    }
  });

  test('telif kaydında her parça var', () {
    final reg = File('docs/music_licenses.md').readAsStringSync();
    for (final t in kMusicTracks) {
      expect(reg.contains('`${t.id}`'), isTrue, reason: 'kayıtta yok: ${t.id}');
    }
  });

  final manifest = File('../ttuncaydemirr-beep.github.io/src/music/manifest.json');
  test('site manifesti (yan klasörde varsa) aynı liste', () {
    final m = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    final tracks = (m['tracks'] as List).cast<Map<String, dynamic>>();
    expect(tracks.map((t) => t['id']).toList(), kMusicTracks.map((t) => t.id).toList());
    for (final t in tracks) {
      final mt = musicTrackById(t['id'] as String)!;
      expect(t['category'], mt.category);
      expect((t['credit'] as String).isNotEmpty, mt.ccBy, reason: '${t['id']}: CC BY ise künye dolu olmalı');
    }
    // Sitenin manifesti dosyaların KAYNAĞIDIR; sunum adresi artık Firebase Hosting (kMusicBaseUrl).
    expect(m['base_url'], anyOf(kMusicBaseUrl, 'https://ttuncaydemirr-beep.github.io/music/'));
  }, skip: manifest.existsSync() ? false : 'site deposu yan klasörde değil');
}
