import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../state/app_state.dart';

/// Uygulama metinleri: assets/l10n/app_<dil>.arb dosyalarından (ARB = JSON) okunur.
///
/// Neden kod üretimi (gen-l10n) değil: derleme makinesi olmadan yazıldığı için
/// Flutter sürümüne bağlı gen-l10n ayar değişikliklerinden etkilenmeyen, çalışma
/// anında okunan basit bir yapı seçildi. ARB biçimi korunduğu için ileride
/// gen-l10n'e geçmek tek adımdır. Anahtar eşitliği test/l10n_keys_test.dart ile denetlenir.
/// Yer tutucular {n}, {p}, {a}, {b}, {d} biçimindedir.
class AppStrings {
  AppStrings(this._maps);

  final Map<String, Map<String, String>> _maps;

  static Future<AppStrings> load() async {
    final maps = <String, Map<String, String>>{};
    for (final lang in kLangs) {
      final raw = await rootBundle.loadString('assets/l10n/app_$lang.arb');
      maps[lang] = parseArb(raw);
    }
    return AppStrings(maps);
  }

  static Map<String, String> parseArb(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, String>{};
    decoded.forEach((k, v) {
      if (!k.startsWith('@')) out[k] = v.toString();
    });
    return out;
  }

  String get(String lang, String key, [Map<String, Object> args = const {}]) {
    var s = _maps[lang]?[key] ?? _maps['tr']?[key] ?? key;
    args.forEach((k, v) {
      s = s.replaceAll('{$k}', '$v');
    });
    return s;
  }
}

extension L10nX on BuildContext {
  /// Arayüz dilinde metin. Ekranlar build içinde `context.watch<AppState>()` çağırdığı
  /// için dil değişince yeniden çizilir; burada dinleme yapılmaz (geri çağrılarda da güvenli).
  String t(String key, [Map<String, Object> args = const {}]) {
    final st = Provider.of<AppState>(this, listen: false);
    return st.strings.get(st.lang, key, args);
  }

  /// Belirli bir dilde metin (ör. davetiye dili).
  String tIn(String lang, String key, [Map<String, Object> args = const {}]) {
    final st = Provider.of<AppState>(this, listen: false);
    return st.strings.get(lang, key, args);
  }
}
