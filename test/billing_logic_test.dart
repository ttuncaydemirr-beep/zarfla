import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/billing/billing_logic.dart';

void main() {
  test('ürün ve bölge sabitleri sunucuyla aynı', () {
    expect(kInviteProductId, 'zarfla_invite_1');
    expect(kFunctionsRegion, 'europe-west3');
    expect(kRedeemFunction, 'redeemPurchase');
  });

  test('sunucu nedenleri → metin anahtarı ve alım eylemi', () {
    void check(String code, String? reason, String key, RedeemAction action) {
      final f = redeemFailureFor(code, reason);
      expect(f.key, key, reason: '$code/$reason');
      expect(f.action, action, reason: '$code/$reason');
    }

    check('already-exists', 'token-used', 'payUsed', RedeemAction.consume);
    check('failed-precondition', 'needs-invite', 'payCredit', RedeemAction.keep);
    check('failed-precondition', 'pending', 'payPending', RedeemAction.keep);
    check('failed-precondition', 'voided', 'payRefunded', RedeemAction.drop);
    check('failed-precondition', 'not-purchased', 'payErr', RedeemAction.drop);
    check('failed-precondition', 'consumed', 'payErr', RedeemAction.drop);
    check('invalid-argument', 'invalid-token', 'payErr', RedeemAction.drop);
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
