import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/ads/ad_config.dart';

void main() {
  test('reklam kimlikleri biçimi geçerli (uygulama kimliği ~, birim kimliği /)', () {
    expect(RegExp(r'^ca-app-pub-\d+~\d+$').hasMatch(kAdMobAndroidAppId), isTrue);
    expect(RegExp(r'^ca-app-pub-\d+/\d+$').hasMatch(kBannerAdUnitId), isTrue);
    expect(RegExp(r'^ca-app-pub-\d+/\d+$').hasMatch(kBannerAdUnitIdRelease), isTrue);
    // Yayın birimi ve uygulama aynı yayıncı hesabından olmalı; test derlemesi Google test birimini kullanır.
    expect(kAdMobAndroidAppId.split('~').first, kBannerAdUnitIdRelease.split('/').first);
    expect(kBannerAdUnitId, startsWith('ca-app-pub-3940256099942544/'));
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

  test('N-6: test bayrağı release derlemede bile Google test birimini seçer; bayraksız release gerçek birimi', () {
    const testUnit = 'ca-app-pub-3940256099942544/9214589741';
    expect(bannerAdUnitIdFor(release: true, testAds: false), kBannerAdUnitIdRelease);
    expect(bannerAdUnitIdFor(release: true, testAds: true), testUnit);
    expect(bannerAdUnitIdFor(release: false, testAds: false), testUnit);
    expect(bannerAdUnitIdFor(release: false, testAds: true), testUnit);
    // Bayrak varsayılan KAPALI (yerel/test derlemesinde dart-define yok); test derlemesi zaten test birimi kullanır.
    expect(kTestAds, isFalse);
    expect(kBannerAdUnitId, testUnit);
    // Birim seçimi tek yerde: AdSlot gerçek birimi doğrudan kullanmaz.
    expect(File('lib/widgets/ad_slot.dart').readAsStringSync(), contains('adUnitId: kBannerAdUnitId'));
    expect(File('lib/widgets/ad_slot.dart').readAsStringSync(), isNot(contains('kBannerAdUnitIdRelease')));
  });

  test('N-6: CI internal/alpha derlemesine ZARFLA_TEST_ADS=true verir, production seçeneği vermez', () {
    final y = File('.github/workflows/build.yml').readAsStringSync();
    expect(y, contains('options: [internal, alpha, production]'));
    expect(y, contains('ZARFLA_TEST_ADS=true'));
    expect(y, contains('"\$TRACK" != "production"'));
    // Bayrak yalnız production dışında eklenir (koşullu değişkenle); sabit olarak her derlemeye yazılmamış olmalı.
    final release = y.substring(y.indexOf('- name: Release AAB'), y.indexOf('- name: İmzayı doğrula'));
    expect(release, contains('\$TEST_ADS_FLAG'));
    expect(release.contains('--dart-define=ZARFLA_TEST_ADS=true --'), isFalse);
    // Varsayılan kanal alpha (test reklamı açık); production yalnız bilinçli seçilir.
    expect(y, contains('default: alpha'));
  });
}
