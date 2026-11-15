import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'ads/ad_service.dart';
import 'app.dart';
import 'billing/billing_service.dart';
import 'cloud/cloud_service.dart';
import 'l10n/strings.dart';
import 'startup/startup_log.dart';
import 'state/app_state.dart';
import 'storage/invitation_store.dart';
import 'storage/photo_store.dart';

/// Açılış: her adım ayrı try/catch + süre sınırı içinde. Hiçbir alt sistem (reklam, ödeme, bulut, geçiş,
/// yazı tipi, metinler) runApp'i engelleyemez; hatalar [StartupLog]'a yazılır ve uygulama açılır.
void main() {
  runZonedGuarded<Future<void>>(_start, (e, st) => StartupLog.record('zone', e, st));
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    StartupLog.record('flutter', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    StartupLog.record('platform', e, st);
    return true; // işlendi: uygulama kapanmaz
  };

  await _step('log', StartupLog.init);
  await _step('ui', () async {
    // Android 15 / targetSdk 35: uçtan uca (edge-to-edge) çizim, tüm sürümlerde tutarlı.
    // Çubuk renkleri bilerek verilmez (eski setStatusBarColor/NavigationBarColor API'leri Play uyarısı üretir);
    // edgeToEdge kipinde çubuklar şeffaf gelir. Zemin açık krem olduğundan simgeler koyu.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ));
  });
  await _step('dates', () => initializeDateFormatting());
  await _step('licenses', () async => _registerFontLicenses());
  final strings = await _value('l10n', AppStrings.load, AppStrings(const {}));
  final photos = PhotoStore();
  final cloud = CloudService(photos);
  await _step('firebase', cloud.init, timeout: const Duration(seconds: 12)); // yerel başlatma; ağ gerektirmez
  final state = AppState(
    strings: strings,
    store: InvitationStore(),
    photos: photos,
    cloud: cloud,
    billing: BillingService(),
  );
  await _step('state', state.init, timeout: const Duration(seconds: 15));
  runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const ZarflaApp()));

  if (StartupLog.safeMode) {
    // Önceki açılış yerel çökmeyle bitti: bu açılışta reklam / ödeme / bulut ısınması başlatılmaz
    // (çökmenin en olası kaynakları). Bir sonraki açılış normal dener.
    debugPrint('zarfla: safe mode (previous launch crashed natively)');
    return;
  }
  // Anonim giriş arka planda (çevrimdışıysa yayın anında yeniden denenir).
  unawaited(_step('cloudWarmUp', state.warmUpCloud, timeout: const Duration(seconds: 60)));
  // Reklam: önce Google UMP rızası, sonra MobileAds başlatılır (arka planda).
  unawaited(_step('ads', () async => AdService.init()));
  // Google Play Faturalandırma: alım akışı, fiyat, yarım kalmış alımları tamamlama (hak ver → tüket).
  unawaited(_step('billing', state.startBilling, timeout: const Duration(seconds: 60)));
}

/// Bir açılış adımını çalıştırır; hata ya da süre aşımı kaydedilir, asla yukarı fırlatılmaz.
Future<void> _step(String name, Future<void> Function() fn, {Duration timeout = const Duration(seconds: 8)}) async {
  try {
    await fn().timeout(timeout);
  } catch (e, st) {
    StartupLog.record('startup.$name', e, st);
  }
}

/// Değer üreten açılış adımı: hata/süre aşımında [fallback] döner.
Future<T> _value<T>(String name, Future<T> Function() fn, T fallback, {Duration timeout = const Duration(seconds: 8)}) async {
  try {
    return await fn().timeout(timeout);
  } catch (e, st) {
    StartupLog.record('startup.$name', e, st);
    return fallback;
  }
}

/// Paketlenen yazı tiplerinin OFL lisansları (Ayarlar > Lisanslar'da görünür).
void _registerFontLicenses() {
  const files = {
    'Fraunces': 'assets/fonts/licenses/OFL-Fraunces.txt',
    'Manrope': 'assets/fonts/licenses/OFL-Manrope.txt',
    'Noto Naskh Arabic': 'assets/fonts/licenses/OFL-NotoNaskhArabic.txt',
    'Amiri': 'assets/fonts/licenses/OFL-Amiri.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final e in files.entries) {
      try {
        final text = await rootBundle.loadString(e.value);
        yield LicenseEntryWithLineBreaks([e.key], text);
      } catch (_) {}
    }
  });
}
