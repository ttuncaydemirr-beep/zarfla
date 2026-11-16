import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/billing/billing_logic.dart';

void main() {
  test('ürün ve bölge sabitleri sunucuyla aynı', () {
    expect(kInviteProductId, 'zarfla_invite_1');
    expect(kBundleProductId, 'zarfla_invite_3');
    expect(kProductIds, {'zarfla_invite_1', 'zarfla_invite_3'});
    expect(kFunctionsRegion, 'europe-west3');
    expect(kRedeemFunction, 'redeemPurchase');
    expect(kUseCreditFunction, 'useCredit');
  });

  test('ürün → hak sayısı (functions/src/logic.js PRODUCT_RIGHTS ile aynı)', () {
    expect(rightsFor(kInviteProductId), 1);
    expect(rightsFor(kBundleProductId), 3);
    expect(rightsFor('zarfla_invite_9'), 0);
    expect(isBundleProduct(kBundleProductId), isTrue);
    expect(isBundleProduct(kInviteProductId), isFalse);
  });

  test('tasarruf yüzdesi Play fiyatlarından hesaplanır', () {
    // TR: 3 × 399 = 1197 → 899 ≈ %25
    expect(bundleSavingsPercent(single: 399, bundle: 899, singleCurrency: 'TRY', bundleCurrency: 'TRY'), 25);
    // EUR: 3 × 9,99 = 29,97 → 22,99 ≈ %23
    expect(bundleSavingsPercent(single: 9.99, bundle: 22.99, singleCurrency: 'EUR', bundleCurrency: 'EUR'), 23);
    // fiyat yok / para birimi farklı / tasarruf yok → rozet yok
    expect(bundleSavingsPercent(single: null, bundle: 899), isNull);
    expect(bundleSavingsPercent(single: 399, bundle: null), isNull);
    expect(bundleSavingsPercent(single: 399, bundle: 899, singleCurrency: 'TRY', bundleCurrency: 'EUR'), isNull);
    expect(bundleSavingsPercent(single: 300, bundle: 900), isNull);
    expect(bundleSavingsPercent(single: 300, bundle: 1000), isNull);
    expect(bundleSavingsPercent(single: 0, bundle: 10), isNull);
  });

  test('ücretli yayın yolu: tüketilmemiş alım > sunucu hakkı > satın alma', () {
    expect(paidRouteFor(balance: 0, hasUnconsumed: false), PaidRoute.buy);
    expect(paidRouteFor(balance: 2, hasUnconsumed: false), PaidRoute.serverCredit);
    expect(paidRouteFor(balance: 2, hasUnconsumed: true), PaidRoute.unconsumed);
    expect(paidRouteFor(balance: 0, hasUnconsumed: true), PaidRoute.unconsumed);
  });

  test('bakiye okuma ve "N hakkınız kaldı" anahtarı', () {
    expect(creditsFromResponse({'ok': true, 'credits': 2}), 2);
    expect(creditsFromResponse({'ok': true, 'credits': 0}), 0);
    expect(creditsFromResponse({'ok': true}), isNull);
    expect(creditsFromResponse({'credits': -1}), isNull);
    expect(creditsFromResponse({'credits': '3'}), isNull);
    expect(balanceFromDoc({'balance': 3, 'lots': []}), 3);
    expect(balanceFromDoc({'balance': -2}), 0);
    expect(balanceFromDoc(null), 0);
    expect(creditsLeftKey(1), 'creditsLeft1');
    expect(creditsLeftKey(2), 'creditsLeft2');
    expect(creditsLeftKey(3), 'creditsLeftN');
  });

  test('sunucu nedenleri → metin anahtarı ve alım eylemi', () {
    void check(String code, String? reason, String key, RedeemAction action) {
      final f = redeemFailureFor(code, reason);
      expect(f.key, key, reason: '$code/$reason');
      expect(f.action, action, reason: '$code/$reason');
    }

    check('already-exists', 'token-used', 'payUsed', RedeemAction.consume);
    check('failed-precondition', 'needs-invite', 'payCredit', RedeemAction.keep);
    check('failed-precondition', 'no-credit', 'creditNone', RedeemAction.keep);
    check('failed-precondition', 'pending', 'payPending', RedeemAction.keep);
    check('failed-precondition', 'voided', 'payRefunded', RedeemAction.drop);
    check('failed-precondition', 'not-purchased', 'payErr', RedeemAction.drop);
    check('failed-precondition', 'consumed', 'payErr', RedeemAction.drop);
    check('invalid-argument', 'invalid-token', 'payErr', RedeemAction.drop);
    check('invalid-argument', 'bad-product', 'payVerifyErr', RedeemAction.keep);
    check('invalid-argument', 'bad-data', 'payDataErr', RedeemAction.keep);
    check('invalid-argument', 'bad-date', 'payDataErr', RedeemAction.keep);
    check('permission-denied', 'not-owner', 'payErr', RedeemAction.keep);
    check('internal', 'publisher-auth', 'payVerifyErr', RedeemAction.keep);
    check('unavailable', 'publisher-unavailable', 'payVerifyErr', RedeemAction.keep);
    check('UNAVAILABLE', null, 'payVerifyErr', RedeemAction.keep);
    check('not-found', 'NOT_FOUND', 'payVerifyErr', RedeemAction.keep);
    check('unauthenticated', 'no-auth', 'cloudDenied', RedeemAction.keep);
  });

  test('bağlam (PendingPaid) JSON gidiş-dönüş ve geçersiz girdiler', () {
    const p = PendingPaid(invId: 'yerel1', cloudId: 'AbCdEf123456');
    final back = PendingPaid.fromJson(p.toJson())!;
    expect(back.invId, 'yerel1');
    expect(back.cloudId, 'AbCdEf123456');
    expect(PendingPaid.fromJson({'inv': 'x', 'cid': 'kisa'}), isNull);
    expect(PendingPaid.fromJson({'inv': '', 'cid': 'AbCdEf123456'}), isNull);
    expect(PendingPaid.fromJson('x'), isNull);
  });
}
