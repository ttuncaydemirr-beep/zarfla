import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/billing/billing_logic.dart';
import 'package:zarfla/cloud/invite_contract.dart';
import 'package:zarfla/logic/share_text.dart';

void main() {
  group('satın alımı geri yükle', () {
    test('hiç alım yok → restoreNone', () {
      expect(restoreMessageKey(const []), 'restoreNone');
    });
    test('hak verildi → restoreDone (diğer sonuçlardan önce)', () {
      expect(restoreMessageKey(const [null]), 'restoreDone');
      expect(restoreMessageKey(const ['payVerifyErr', null], pending: 1), 'restoreDone');
      expect(restoreMessageKey(const ['paidPhotoErr']), 'restoreDone');
    });
    test('kullanılmamış hak → restoreCredit', () {
      expect(restoreMessageKey(const ['payCredit']), 'restoreCredit');
      expect(restoreMessageKey(const ['payCredit', 'payVerifyErr']), 'restoreCredit');
    });
    test('beklemede → restorePending', () {
      expect(restoreMessageKey(const [], pending: 1), 'restorePending');
      expect(restoreMessageKey(const ['payPending']), 'restorePending');
      expect(restoreMessageKey(const ['payProcessing']), 'restorePending');
    });
    test('doğrulanamadı / sorgu hatası → restoreErr', () {
      expect(restoreMessageKey(const ['payVerifyErr']), 'restoreErr');
      expect(restoreMessageKey(const ['cloudDenied']), 'restoreErr');
      expect(restoreMessageKey(const [], queryFailed: true), 'restoreErr');
    });
    test('tüketilmiş / iade edilmiş → restoreNone', () {
      expect(restoreMessageKey(const ['payUsed']), 'restoreNone');
      expect(restoreMessageKey(const ['payRefunded', 'payUsed']), 'restoreNone');
    });
    test('doğrulama bandı', () {
      expect(needsVerifyBanner(const []), isFalse);
      expect(needsVerifyBanner(const [null]), isFalse);
      expect(needsVerifyBanner(const ['payCredit']), isFalse);
      expect(needsVerifyBanner(const ['payUsed', 'payRefunded']), isFalse);
      expect(needsVerifyBanner(const [], pending: 1), isTrue);
      expect(needsVerifyBanner(const ['payVerifyErr']), isTrue);
      expect(isUnverifiedResult(null), isFalse);
      expect(isUnverifiedResult('payPending'), isTrue);
    });
  });

  group('kişiye özel bağlantı', () {
    test('ad temizleme: kırpma, boşluk, kontrol ve yön karakterleri', () {
      expect(cleanGuestName('  Ayşe   Teyze \n'), 'Ayşe Teyze');
      expect(cleanGuestName('A\u0000B\u202eC\u200bD'), 'A B C D');
      expect(cleanGuestName('\t\r '), '');
    });
    test('en çok 60 kod noktası (emoji bölünmez)', () {
      expect(cleanGuestName('a' * 80).length, kGuestNameMax);
      final e = cleanGuestName('😀' * 70);
      expect(e.runes.length, kGuestNameMax);
    });
    test('satır satır isim listesi: boşlar atlanır, tekrarlar tekilleşir', () {
      expect(parseGuestNames('Ali\n\n  ali \r\nMehmet Bey\n   \nZeynep'), ['Ali', 'Mehmet Bey', 'Zeynep']);
      expect(parseGuestNames(List.generate(80, (i) => 'K$i').join('\n')).length, kGuestLinksMax);
      expect(parseGuestNames(''), isEmpty);
    });
    test('bağlantı biçimi ve URL kodlama', () {
      const id = 'AbCdEf123456';
      expect(personalInviteUrl(id, 'Ayşe & Can'),
          'https://zarfla-37da9.web.app/davetiye/?id=AbCdEf123456&g=Ay%C5%9Fe%20%26%20Can');
      expect(personalInviteUrl(id, '   '), inviteUrl(id));
      final u = Uri.parse(personalInviteUrl(id, 'محمد + ليلى'));
      expect(u.queryParameters['id'], id);
      expect(u.queryParameters['g'], 'محمد + ليلى');
    });
  });

  test('kişiye özel paylaşım metni', () {
    expect(personalShareText(hiTpl: 'Sevgili {g},', guest: ' Ayşe ', body: 'A\nB'), 'Sevgili Ayşe,\nA\nB');
    expect(personalShareText(hiTpl: 'Dear {g},', guest: '', body: 'X'), 'X');
  });
}
