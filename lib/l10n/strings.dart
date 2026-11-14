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

  /// Anahtar bu dilde (ya da Türkçe yedekte) tanımlı mı?
  bool has(String lang, String key) => (_maps[lang]?.containsKey(key) ?? false) || (_maps['tr']?.containsKey(key) ?? false);

  String get(String lang, String key, [Map<String, Object> args = const {}]) {
    var s = _maps[lang]?[key] ?? _maps['tr']?[key] ?? key;
    args.forEach((k, v) {
      s = s.replaceAll('{$k}', '$v');
    });
    return s;
  }
}

/// Dil değişince `context.t` kullanan TÜM widget'ları (const olanlar dahil) yeniden çizdirir.
/// Kök neden: `const _Empty()` gibi const widget'lar üst widget yeniden çizilince de
/// atlanır; `context.t` bağımlılık kaydetmediği için metin eski dilde kalıyordu.
class LangScope extends InheritedWidget {
  const LangScope({super.key, required this.lang, required super.child});

  final String lang;

  @override
  bool updateShouldNotify(LangScope oldWidget) => oldWidget.lang != lang;
}

extension L10nX on BuildContext {
  /// Arayüz dilinde metin. [LangScope] bağımlılığı sayesinde dil değişince build içinde
  /// çağıran her widget yeniden çizilir (geri çağrılarda da güvenli).
  String t(String key, [Map<String, Object> args = const {}]) {
    try {
      if (mounted) dependOnInheritedWidgetOfExactType<LangScope>();
    } catch (_) {
      // initState gibi bağımlılık kaydedilemeyen yerlerde sessizce geç.
    }
    final st = Provider.of<AppState>(this, listen: false);
    return st.strings.get(st.lang, key, args);
  }

  /// [key] tanımlıysa onu, değilse [fallbackKey] metnini verir (ör. türe özel tek isim etiketi).
  String tOr(String key, String fallbackKey) {
    final st = Provider.of<AppState>(this, listen: false);
    return t(st.strings.has(st.lang, key) ? key : fallbackKey);
  }

  /// Belirli bir dilde metin (ör. davetiye dili).
  String tIn(String lang, String key, [Map<String, Object> args = const {}]) {
    final st = Provider.of<AppState>(this, listen: false);
    return st.strings.get(lang, key, args);
  }
}
