import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarfla/data/catalog.dart';
import 'package:zarfla/l10n/strings.dart';
import 'package:zarfla/widgets/terms_note.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('koşullar bağlantısı stüdyo sitesinde (terms/zarfla)', () {
    expect(kTermsUrl, 'https://ttuncaydemirr-beep.github.io/terms/zarfla/');
  });

  test('kabul yerel saklanır: ilk yayına kadar yok, sonra kalıcı ve ilk zaman korunur', () async {
    expect(await TermsConsent.isAccepted(), isFalse);
    await TermsConsent.accept(1000);
    expect(await TermsConsent.isAccepted(), isTrue);
    await TermsConsent.accept(2000);
    expect((await SharedPreferences.getInstance()).getInt(kTermsAcceptedKey), 1000);
  });

  test('koşul satırı dört dilde var ve {n} yer tutucusu içeriyor', () {
    for (final l in kLangs) {
      final m = AppStrings.parseArb(File('assets/l10n/app_$l.arb').readAsStringSync());
      expect(m['termsConsent'], contains('{n}'), reason: l);
      expect(m['termsLinkText'], isNotEmpty, reason: l);
    }
  });

  test('yayın ekranı koşul satırını yalnız kabul edilmemişse gösterir ve düğmeye basınca kabul eder', () {
    final src = File('lib/screens/publish_screen.dart').readAsStringSync();
    expect(src, contains('terms: _termsAccepted == false'));
    expect(src, contains('TermsConsent.accept()'));
    expect(src, contains('TermsConsentNote()'));
  });
}
