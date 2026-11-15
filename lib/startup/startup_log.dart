import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CI'da `--dart-define=ZARFLA_BUILD=<versionCode>` ile verilir (Play'deki sürüm kodu). Yerelde 0.
const int kBuildNumber = int.fromEnvironment('ZARFLA_BUILD', defaultValue: 0);

/// Görünen sürüm adı: Play'deki versionName ile aynı ("1.0.<versionCode>").
String get appVersionName => kBuildNumber > 0 ? '1.0.$kBuildNumber' : '1.0.0';

/// Açılış ve çalışma hataları kaydı. Hiçbir hata uygulamayı kapatmaz: kaydedilir ve devam edilir.
///
/// - Dart hataları (FlutterError, PlatformDispatcher, zone) [record] ile tutulur ve cihazda saklanır.
/// - Yerel (Kotlin/Java) çökmeleri ZarflaApplication tarafından `files/zarfla_last_crash.txt` dosyasına
///   yazılır. Bir sonraki açılışta okunur: o açılış "güvenli kip"tir (reklam, ödeme ve bulut ısınması
///   başlatılmaz) ve ayrıntı "⋯ > Hakkında" ekranında gösterilir (kopyalanıp geliştiriciye iletilebilir).
class StartupLog {
  StartupLog._();

  static const String prefsKey = 'zarfla_err_log_v1';
  static const String nativeCrashFile = 'zarfla_last_crash.txt';
  static const String nativeCrashSeenFile = 'zarfla_last_crash_seen.txt';
  static const int maxEntries = 30;

  /// Bu oturum + önceki oturumların hata satırları (en yeni sonda).
  static final List<String> entries = <String>[];

  /// En son görülen yerel çökme metni (yoksa null).
  static String? nativeCrash;

  /// Bir önceki açılış yerel çökmeyle bittiyse true: bu açılışta riskli alt sistemler başlatılmaz.
  static bool safeMode = false;

  static String? _last;
  static int _repeat = 0;

  /// Hata kaydı. ASLA istisna fırlatmaz.
  static void record(String where, Object error, [StackTrace? stack]) {
    try {
      final head = '$where: $error';
      if (head == _last) {
        _repeat++;
        if (_repeat > 3) return; // aynı hata her karede yinelenirse kaydı şişirme
      } else {
        _last = head;
        _repeat = 0;
      }
      final st = stack == null ? '' : '\n${_shortStack(stack)}';
      final line = '[${DateTime.now().toIso8601String()} v$appVersionName] $head$st';
      debugPrint('zarfla error: $line');
      entries.add(line);
      while (entries.length > maxEntries) {
        entries.removeAt(0);
      }
      _persist();
    } catch (_) {}
  }

  static String _shortStack(StackTrace s) {
    final lines = s.toString().split('\n').where((l) => l.trim().isNotEmpty).take(8);
    return lines.join('\n');
  }

  static Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(prefsKey, jsonEncode(entries));
    } catch (_) {}
  }

  /// Önceki oturumların kaydını ve (varsa) yerel çökme dosyasını yükler. ASLA istisna fırlatmaz.
  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.get(prefsKey);
      if (raw is String && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) {
          entries.insertAll(0, d.whereType<String>());
          while (entries.length > maxEntries) {
            entries.removeAt(0);
          }
        }
      }
    } catch (_) {}
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$nativeCrashFile');
      final seen = File('${dir.path}/$nativeCrashSeenFile');
      if (await f.exists()) {
        nativeCrash = await f.readAsString();
        safeMode = true;
        try {
          if (await seen.exists()) await seen.delete();
          await f.rename(seen.path);
        } catch (_) {
          try {
            await f.delete();
          } catch (_) {}
        }
      } else if (await seen.exists()) {
        nativeCrash = await seen.readAsString();
      }
    } catch (_) {}
  }

  /// "Hakkında" ekranında gösterilecek/kopyalanacak tam metin.
  static String report() {
    final b = StringBuffer('Zarfla $appVersionName (build $kBuildNumber)\n');
    if (safeMode) b.writeln('SAFE MODE (previous launch crashed)');
    final n = nativeCrash;
    if (n != null && n.trim().isNotEmpty) {
      b
        ..writeln('--- native crash ---')
        ..writeln(n.trim());
    }
    if (entries.isNotEmpty) {
      b.writeln('--- errors ---');
      for (final e in entries.reversed.take(15)) {
        b.writeln(e);
      }
    }
    return b.toString();
  }

  static bool get hasProblems => safeMode || (nativeCrash?.trim().isNotEmpty ?? false) || entries.isNotEmpty;

  /// Kaydı temizle (Hakkında > Temizle).
  static Future<void> clear() async {
    entries.clear();
    nativeCrash = null;
    _last = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(prefsKey);
    } catch (_) {}
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final seen = File('${dir.path}/$nativeCrashSeenFile');
      if (await seen.exists()) await seen.delete();
    } catch (_) {}
  }
}
