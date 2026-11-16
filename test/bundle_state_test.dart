import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarfla/billing/billing_logic.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/state/app_state.dart';
import 'package:zarfla/storage/invitation_store.dart';
import 'package:zarfla/storage/photo_store.dart';
import 'package:zarfla/theme/app_theme.dart';
import 'package:zarfla/widgets/restore_purchases.dart';

/// "Düğün Zinciri" (3 hak): durum kuralları, metinler ve kalan hak göstergesi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppStrings arbStrings() => AppStrings({
        for (final l in kLangs) l: AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync()),
      });

  AppState make() {
    SharedPreferences.setMockInitialValues({});
    return AppState(strings: arbStrings(), store: InvitationStore(), photos: PhotoStore());
  }

  test('bakiye yokken: hak yok, ödeme/hak düğmesi kapalı, paket kartı (Play fiyatı yok) gizli', () {
    final st = make();
    expect(st.creditBalance, 0);
    expect(st.hasCredit, isFalse);
    expect(st.hasUnconsumed, isFalse);
    expect(st.canPayOrUseCredit, isFalse);
    expect(st.bundlePrice, isNull);
    expect(st.bundleSavePct, isNull);
  });

  test('sunucuda paket hakkı varsa Play olmadan da ücretli yayın düğmesi çalışır', () {
    final st = make()..creditBalance = 2;
    expect(st.hasCredit, isTrue);
    expect(st.hasUnconsumed, isFalse);
    expect(st.canPayOrUseCredit, isTrue);
  });

  test('bulut yoksa ücretli yayın (paket dahil) güvenle reddedilir, hak düşülmez', () async {
    final st = make()..creditBalance = 2;
    final inv = Invitation.create(id: 'x1', type: 'dugun', lang: 'tr', now: 1);
    expect(await st.publishPaid(inv, productId: kBundleProductId), 'cloudSetup');
    expect(st.creditBalance, 2);
  });

  test('yeni metinler 4 dilde var; tasarruf rozeti yer tutucu {n} içerir', () {
    final s = arbStrings();
    for (final l in kLangs) {
      for (final k in ['bundleName', 'bundleSub', 'bundleP', 'bundleSave', 'creditsLeft1', 'creditsLeft2', 'creditsLeftN',
        'creditsLeftP', 'creditWillUse', 'creditOne', 'creditNone', 'restoreCreditsLeft']) {
        expect(s.has(l, k), isTrue, reason: '$l.$k');
      }
      expect(s.get(l, 'bundleSave', {'n': 25}), contains('25'), reason: l);
      expect(s.get(l, 'creditsLeftN', {'n': 3}), contains('3'), reason: l);
    }
    expect(s.get('tr', 'bundleSave', {'n': 25}), '≈%25 tasarruf');
    expect(s.get('tr', 'creditsLeft2'), '2 Davetiye Hakkınız kaldı');
    expect(s.get('tr', 'bundleName'), 'Düğün Zinciri');
  });

  for (final lang in ['tr', 'ar']) {
    testWidgets('kalan hak göstergesi ($lang): 0 iken gizli, 2 iken görünür, taşma yok', (tester) async {
      final st = make();
      await st.setLang(lang);
      Widget app() => ChangeNotifierProvider<AppState>.value(
            value: st,
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Directionality(
                textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                child: const Scaffold(body: SizedBox(width: 320, child: CreditsBadge())),
              ),
            ),
          );
      await tester.pumpWidget(app());
      expect(find.text(st.t('creditsLeft2')), findsNothing);
      st.creditBalance = 2;
      await st.setLang(lang); // dinleyicileri uyandırır
      await tester.pump();
      expect(find.text(st.t('creditsLeft2')), findsOneWidget);
      expect(find.text(st.t('creditsLeftP')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
