import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/logic/validation.dart';
import 'package:zarfla/models/invitation.dart';

Invitation _inv(String type) => Invitation.create(id: 'test01', type: type, lang: 'tr', now: 0);

void main() {
  group('WhatsApp numarası', () {
    test('ülke koduyla geçerli', () {
      expect(isValidWhatsApp('90 555 111 22 33'), isTrue);
      expect(isValidWhatsApp('+49 151 2345678'), isTrue);
    });
    test('0 ile başlayan, kısa ya da uzun numara geçersiz', () {
      expect(isValidWhatsApp('0555 111 22 33'), isFalse);
      expect(isValidWhatsApp('905551112'), isFalse); // 9 rakam
      expect(isValidWhatsApp('9055511122334455'), isFalse); // 16 rakam
      expect(isValidWhatsApp(''), isFalse);
    });
  });

  group('validateInvitation', () {
    test('boş çift davetiyesinde tüm hatalar', () {
      final e = validateInvitation(_inv('dugun')..time = '');
      expect(e['names'], 'reqNames');
      expect(e['date'], 'reqDate');
      expect(e['venue'], 'reqVenue');
      expect(e['wa'], 'reqWa');
    });
    test('tek isimli türde reqName; ikinci isim aranmaz', () {
      final inv = _inv('dogum');
      expect(validateInvitation(inv)['names'], 'reqName');
      inv.n1 = 'Ali';
      expect(validateInvitation(inv).containsKey('names'), isFalse);
    });
    test('çiftte iki isim de gerekli; boşluk isim sayılmaz', () {
      final inv = _inv('nisan')
        ..n1 = 'Test A'
        ..n2 = '   ';
      expect(validateInvitation(inv)['names'], 'reqNames');
    });
    test('eksiksiz davetiye geçer', () {
      final inv = _inv('nisan')
        ..n1 = 'Test A'
        ..n2 = 'Test B'
        ..date = '2027-06-12'
        ..time = '19:00'
        ..venue = 'Test Venue'
        ..wa = '905551112233';
      expect(validateInvitation(inv), isEmpty);
    });
  });
  group('canlı yayın ve hediye IBAN doğrulaması', () {
    Invitation full() => _inv('nisan')
      ..n1 = 'Test A'
      ..n2 = 'Test B'
      ..date = '2027-06-12'
      ..venue = 'Test Venue'
      ..wa = '905551112233';

    test('geçersiz canlı yayın bağlantısı hata verir, boş serbest', () {
      expect(validateInvitation(full()..liveUrl = 'http://x.com/a')['live'], 'streamErr');
      expect(validateInvitation(full()..liveUrl = 'javascript:alert(1)')['live'], 'streamErr');
      expect(validateInvitation(full()..liveUrl = 'https://youtu.be/abc'), isEmpty);
      expect(validateInvitation(full()), isEmpty);
    });

    test('IBAN: ücretli taslakta (ücretli tasarım) doğrulanır; ücretsizde yok sayılır', () {
      final paid = full()
        ..theme = 'altin'
        ..giftIban = 'TR330006100519786457841327';
      var e = validateInvitation(paid);
      expect(e['giftIban'], 'giftErrIban');
      expect(e['giftHolder'], 'giftErrHolder');
      paid
        ..giftIban = 'TR330006100519786457841326'
        ..giftHolder = 'Ali Demir';
      expect(validateInvitation(paid), isEmpty);
      final free = full()
        ..theme = 'papatya'
        ..giftIban = 'bozuk';
      expect(validateInvitation(free), isEmpty);
      // yayındaki ücretli davetiye
      final live = full()
        ..plan = 'premium'
        ..status = 'live'
        ..giftIban = 'bozuk';
      e = validateInvitation(live);
      expect(e['giftIban'], 'giftErrIban');
    });
  });
}
