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

    test('varsayılan ülke kodu: cihaz bölgesi, yoksa dil', () {
      expect(defaultDial(deviceCountry: 'DE', lang: 'tr'), '49');
      expect(defaultDial(deviceCountry: 'kz', lang: 'tr'), '7');
      expect(defaultDial(deviceCountry: 'CA', lang: 'tr'), '1');
      expect(defaultDial(deviceCountry: 'BR', lang: 'ar'), '966');
      expect(defaultDial(lang: 'de'), '49');
      expect(defaultDial(lang: 'en'), '44');
    });

    test('ülke listesinde çevirme kodları benzersiz, bayrak 2 sembol', () {
      final dials = kCountries.map((c) => c.dial).toList();
      expect(dials.toSet().length, dials.length);
      expect(kCountries.first.flag.runes.length, 2);
    });
  });
}
