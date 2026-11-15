import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'ads/ad_service.dart';
import 'app.dart';
import 'cloud/cloud_service.dart';
import 'l10n/strings.dart';
import 'state/app_state.dart';
import 'storage/invitation_store.dart';
import 'storage/photo_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  _registerFontLicenses();
  final strings = await AppStrings.load();
  final photos = PhotoStore();
  final cloud = CloudService(photos);
  await cloud.init(); // yerel başlatma; ağ gerektirmez
  final state = AppState(strings: strings, store: InvitationStore(), photos: photos, cloud: cloud);
  await state.init();
  runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const ZarflaApp()));
  // Anonim giriş arka planda (çevrimdışıysa yayın anında yeniden denenir).
  state.warmUpCloud();
  // Reklam: önce Google UMP rızası, sonra MobileAds başlatılır (arka planda).
  AdService.init();
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
