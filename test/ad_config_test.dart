import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/ads/ad_config.dart';

void main() {
  test('reklam kimlikleri biçimi geçerli (uygulama kimliği ~, birim kimliği /)', () {
    expect(RegExp(r'^ca-app-pub-\d+~\d+$').hasMatch(kAdMobAndroidAppId), isTrue);
    expect(RegExp(r'^ca-app-pub-\d+/\d+$').hasMatch(kBannerAdUnitId), isTrue);
    // Uygulama ve birim aynı yayıncı hesabından olmalı.
    expect(kAdMobAndroidAppId.split('~').first, kBannerAdUnitId.split('/').first);
  });

  test('patch_android.py uygulama kimliğini ad_config.dart içinden okur (satır biçimi korunmuş)', () {
    final dart = File('lib/ads/ad_config.dart').readAsStringSync();
    expect(RegExp(r"kAdMobAndroidAppId\s*=\s*'(ca-app-pub-\d+~\d+)'").hasMatch(dart), isTrue);
    final py = File('scripts/patch_android.py').readAsStringSync();
    expect(py, contains('kAdMobAndroidAppId'));
    expect(py, contains('com.google.android.gms.permission.AD_ID'));
  });

  test('reklam yalnız izin verilen ekranlarda: misafir/editör/yayın ekranlarında AdSlot yok', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final path = f.path.replaceAll('\\', '/');
      final uses = f.readAsStringSync().contains('AdSlot(');
      const allowed = {'lib/screens/home_screen.dart', 'lib/screens/theme_screen.dart', 'lib/widgets/ad_slot.dart'};
      if (uses) expect(allowed, contains(path), reason: '$path içinde AdSlot olmamalı');
    }
  });

  test('banner ekranın altına sabit: kaydırılan listenin/ızgaranın dışında, Expanded\'dan sonra', () {
    for (final path in ['lib/screens/home_screen.dart', 'lib/screens/theme_screen.dart']) {
      final src = File(path).readAsStringSync();
      final ad = src.indexOf('AdSlot(');
      expect(ad, greaterThan(0), reason: path);
      expect(ad, greaterThan(src.indexOf('Expanded(')), reason: '$path: AdSlot kaydırılan alanın içinde');
      expect(src.contains('SliverToBoxAdapter(child: st.premiumUser ? const SizedBox.shrink() : const AdSlot())'), isFalse);
    }
    expect(File('lib/screens/home_screen.dart').readAsStringSync().indexOf('AdSlot('),
        greaterThan(File('lib/screens/home_screen.dart').readAsStringSync().indexOf("context.t('newInv')")));
  });
}
