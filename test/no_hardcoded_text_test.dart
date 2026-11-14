import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/logic/sample_names.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/models/invitation.dart';

/// lib/ içinde kullanıcıya görünen sabit Türkçe metin kalmadığını denetler.
/// AÇIK İSTİSNALAR (bilinçli):
///  - lib/data/catalog.dart: çok dilli veri katalogları (tasarım adları, hazır davet mesajları, dil adları)
///  - lib/logic/text_utils.dart: Türkçe büyük harf mantığı (i→İ, ı→I), metin değil
///  - lib/logic/sample_names.dart: eski örnek isimleri temizleyen tek seferlik geçiş listesi
///  - yorum satırları (// ve ///)
void main() {
  const exemptFiles = {
    'lib/data/catalog.dart',
    'lib/logic/text_utils.dart',
    'lib/logic/sample_names.dart',
  };
  final turkish = RegExp('[ğüşıöçİĞÜŞÖÇ]');

  test('lib/ içinde Türkçe karakterli string literal yok (istisnalar hariç)', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || exemptFiles.contains(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        final c = line.indexOf('//');
        if (c >= 0) line = line.substring(0, c);
        if (turkish.hasMatch(line)) bad.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(bad, isEmpty, reason: 'Sabit yazılmış Türkçe metin:\n${bad.join('\n')}');
  });

  test('ARB, invite.html ve lib/ içinde örnek kişi/aile adı kalmadı', () {
    final names = [...kLegacySampleNames, ...kLegacySampleHosts, 'Baler Garden', 'Avcılar', 'Miller', 'Weber'];
    final files = <File>[
      ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) {
        final p = f.path.replaceAll('\\', '/');
        return p.endsWith('.dart') && !exemptFiles.contains(p);
      }),
      File('assets/invite/invite.html'),
      for (final l in kLangs) File('assets/l10n/app_$l.arb'),
    ];
    for (final f in files) {
      var text = f.readAsStringSync();
      // invite.html içindeki tasarım görünen adları ("Deniz Altı" gibi) kişi adı değildir.
      if (f.path.endsWith('invite.html')) text = text.replaceAll(RegExp(r'"name":\{[^}]*\}'), '');
      for (final n in names) {
        expect(RegExp('(?<![\\p{L}])${RegExp.escape(n)}(?![\\p{L}])', unicode: true).hasMatch(text), isFalse,
            reason: '${f.path} içinde örnek ad: $n');
      }
    }
  });

  test('dil değişince sabit metin yok: tüm ARB anahtarları kodda kullanılan her t() için var', () {
    final maps = {
      for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
    };
    final used = RegExp(r"""\bt\('([A-Za-z0-9_]+)'""");
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in used.allMatches(f.readAsStringSync())) {
        for (final l in kLangs) {
          expect(maps[l]!.containsKey(m.group(1)), isTrue, reason: '${f.path}: ${m.group(1)} ($l) ARB\'de yok');
        }
      }
    }
  });

  test('geçiş: taslaktaki birebir örnek adlar temizlenir, kullanıcının adına ve yayındakine dokunulmaz', () {
    final d = Invitation(id: 'x', type: 'nisan', theme: 'papatya', lang: 'tr', created: 0, n1: 'Pelin Su', n2: 'Zeynep', host: 'Miller and Smith families');
    expect(clearSampleNames(d), isTrue);
    expect(d.n1, '');
    expect(d.n2, 'Zeynep');
    expect(d.host, '');
    final live = Invitation(id: 'y', type: 'nisan', theme: 'papatya', lang: 'tr', created: 0, n1: 'Burak', status: 'live');
    expect(clearSampleNames(live), isFalse);
    expect(live.n1, 'Burak');
  });
}
