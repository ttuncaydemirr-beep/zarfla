import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/data/countries.dart';
import 'package:zarfla/logic/phone.dart';

void main() {
  group('normalizeLocalInput', () {
    test('baştaki 0 ve biçim karakterleri atılır, +90 ile birleşir', () {
      final r = normalizeLocalInput('0532 123 45 67', '90');
      expect(r.parts.dial, '90');
      expect(r.parts.local, '5321234567');
      expect(r.changed, isTrue);
      expect(composeWa(r.parts.dial, r.parts.local), '905321234567');
    });

    test('yerel numara olduğu gibi yazılırken metne dokunulmaz', () {
      final r = normalizeLocalInput('532 123', '90');
      expect(r.changed, isFalse);
      expect(r.parts.local, '532123');
    });

    test('+49 ile yapıştırılan numara ülkeyi seçer', () {
      final r = normalizeLocalInput('+49 151 2345678', '90');
      expect(r.parts.dial, '49');
      expect(r.parts.local, '1512345678');
      expect(composeWa(r.parts.dial, r.parts.local), '491512345678');
    });

    test('00966 ile yapıştırılan numara Suudi Arabistan olur', () {
      final r = normalizeLocalInput('00966 50 123 4567', '90');
      expect(r.parts.dial, '966');
      expect(r.parts.local, '501234567');
      expect(composeWa(r.parts.dial, r.parts.local), '966501234567');
    });

    test('kod yazılırken (+, +3, 00) metne dokunulmaz', () {
      for (final s in ['+', '+3', '+35', '00']) {
        expect(normalizeLocalInput(s, '90').changed, isFalse, reason: s);
      }
    });

    test('listede olmayan ülke diğer moduna geçer', () {
      final r = normalizeLocalInput('+55 11 91234 5678', '90');
      expect(r.parts.dial, '');
      expect(composeWa(r.parts.dial, r.parts.local), '5511912345678');
    });
  });

  group('parsePhone', () {
    test('kayıtlı 905321234567 → +90 / 5321234567', () {
      final p = parsePhone('905321234567', fallbackDial: '49');
      expect(p.dial, '90');
      expect(p.local, '5321234567');
    });

    test('artı ve boşluklu kayıt', () {
      final p = parsePhone('+49 151 2345678', fallbackDial: '90');
      expect(p.dial, '49');
      expect(p.local, '1512345678');
    });

    test('en uzun önek eşleşir (966 / 971 gibi üç haneli kodlar)', () {
      expect(parsePhone('971501234567', fallbackDial: '90').dial, '971');
      expect(parsePhone('359881234567', fallbackDial: '90').dial, '359');
      expect(parsePhone('15551234567', fallbackDial: '90').dial, '1');
    });

    test('eski bozuk kayıt (başında 0) varsayılan ülkeyle yerel sayılır', () {
      final p = parsePhone('05321234567', fallbackDial: '90');
      expect(p.dial, '90');
      expect(p.local, '5321234567');
    });

    test('bilinmeyen ülke korunur, boş kayıt varsayılanı alır', () {
      final p = parsePhone('5511912345678', fallbackDial: '90');
      expect(p.dial, '');
      expect(p.local, '5511912345678');
      final e = parsePhone('', fallbackDial: '49');
      expect(e.dial, '49');
      expect(e.local, '');
    });
  });

  group('composeWa / doğrulama / varsayılan', () {
    test('boş yerel numara boş saklanır', () {
      expect(composeWa('90', ''), '');
      expect(composeWa('90', ' 0 '), '');
    });

    test('yerel numara 6–14 rakam', () {
      expect(isValidLocalNumber('12345'), isFalse);
      expect(isValidLocalNumber('123 456'), isTrue);
      expect(isValidLocalNumber('12345678901234'), isTrue);
      expect(isValidLocalNumber('123456789012345'), isFalse);
    });

    test('varsayılan ülke kodu: önce davetiye dili, dil eşlemesi yoksa cihaz bölgesi (UX #6)', () {
      expect(defaultDial(deviceCountry: 'DE', lang: 'tr'), '90');
      expect(defaultDial(deviceCountry: 'BR', lang: 'ar'), '966');
      expect(defaultDial(lang: 'de'), '49');
      expect(defaultDial(lang: 'en'), '44');
      expect(defaultDial(deviceCountry: 'kz', lang: 'xx'), '7');
      expect(defaultDial(deviceCountry: 'CA', lang: 'xx'), '1');
      expect(defaultDial(lang: 'xx'), '90');
      expect(dialForCountry('at'), '43');
      expect(dialForCountry('BR'), isNull);
    });

    test('cihaz bölgesi seçili koddan farklıysa seçici öne çıkarılır', () {
      expect(deviceDialHint(deviceCountry: 'DE', currentDial: '90'), '49');
      expect(deviceDialHint(deviceCountry: 'TR', currentDial: '90'), isNull);
      expect(deviceDialHint(deviceCountry: 'BR', currentDial: '90'), isNull);
      expect(deviceDialHint(currentDial: '90'), isNull);
    });

    test('başka ülkenin cep numarası kalıbı: satır içi öneri', () {
      // +49 seçiliyken 10 haneli 5XX numarası → Türkiye önerilir.
      expect(suggestDial('532 123 45 67', '49'), '90');
      expect(suggestDial('5321234567', '44'), '90');
      // Seçili ülkenin kendi kalıbına uyuyorsa öneri yok.
      expect(suggestDial('5321234567', '90'), isNull);
      expect(suggestDial('151 23456789', '49'), isNull);
      // +90 seçiliyken Alman / İngiliz cep numarası.
      expect(suggestDial('15123456789', '90'), '49');
      expect(suggestDial('7911123456', '90'), '44');
      // Kısa / eksik numara, "diğer" ya da boş: öneri yok.
      expect(suggestDial('532123', '49'), isNull);
      expect(suggestDial('5321234567', ''), isNull);
      expect(suggestDial('', '49'), isNull);
      // Körfez numaraları (9 hane, 5 ile başlar) Türkiye sanılmaz.
      expect(suggestDial('501234567', '971'), isNull);
    });

    test('canlı önizleme için numara biçimi', () {
      expect(formatLocalNumber('90', '5321234567'), '532 123 45 67');
      expect(formatLocalNumber('49', '1512345678'), '151 234 5678');
      expect(formatLocalNumber('49', '15123456789'), '151 234 567 89');
      expect(formatLocalNumber('44', '7911123456'), '791 112 3456');
      expect(formatLocalNumber('90', ''), '');
    });

    test('ülke adları dört dilde, her ülke için', () {
      for (final l in ['tr', 'en', 'de', 'ar']) {
        for (final c in kCountries) {
          expect(kCountryNamesByLang[l]![c.iso], isNotNull, reason: '$l/${c.iso}');
        }
      }
      expect(countryNameIn(countryByDial('90')!, 'ar'), 'تركيا');
      expect(countryNameIn(countryByDial('49')!, 'tr'), 'Almanya');
      expect(countryByDial('000'), isNull);
    });

    test('ülke listesinde çevirme kodları benzersiz, bayrak 2 sembol', () {
      final dials = kCountries.map((c) => c.dial).toList();
      expect(dials.toSet().length, dials.length);
      expect(kCountries.first.flag.runes.length, 2);
    });
  });
}
