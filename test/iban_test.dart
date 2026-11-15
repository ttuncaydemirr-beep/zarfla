import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/logic/iban.dart';

void main() {
  const valid = [
    'TR330006100519786457841326', 'DE89370400440532013000', 'AT611904300234573201', 'CH9300762011623852957',
    'NL91ABNA0417164300', 'BE68539007547034', 'FR1420041010050500013M02606', 'GB82WEST12345698765432',
    'SA0380000000608010167519', 'AE070331234567890123456', 'QA58DOHB00001234567890ABCDEFG',
    'KW81CBKU0000000000001234560101', 'BH67BMAG00001299123456', 'IT60X0542811101000000123456',
  ];

  test('gerçek geçerli IBAN örnekleri kabul edilir (bitişik, boşluklu, küçük harf)', () {
    for (final v in valid) {
      expect(isValidIban(v), isTrue, reason: v);
      expect(isValidIban(formatIban(v)), isTrue, reason: v);
      expect(isValidIban(v.toLowerCase()), isTrue, reason: v);
    }
  });

  test('sağlama toplamı, uzunluk, ülke ve biçim hataları reddedilir', () {
    expect(isValidIban('TR330006100519786457841327'), isFalse); // son hane yanlış
    expect(isValidIban('DE89370400440532013001'), isFalse);
    expect(isValidIban('TR33000610051978645784132'), isFalse); // bir hane eksik
    expect(isValidIban('TR3300061005197864578413260'), isFalse); // bir hane fazla
    expect(isValidIban('XX89370400440532013000'), isFalse); // bilinmeyen ülke
    expect(isValidIban('1234567890'), isFalse);
    expect(isValidIban(''), isFalse);
    expect(isValidIban('DE89 3704 0044 0532 0130 0!'), isFalse);
  });

  test('normalizeIban ve formatIban', () {
    expect(normalizeIban(' tr33 0006-1005.1978 6457 8413 26 '), 'TR330006100519786457841326');
    expect(formatIban('tr330006100519786457841326'), 'TR33 0006 1005 1978 6457 8413 26');
    expect(formatIban('DE89370400440532013000'), 'DE89 3704 0044 0532 0130 00');
  });

  test('cleanGiftText kontrol karakterlerini atar ve kısaltır', () {
    expect(cleanGiftText('  Ali\nVeli\t Demir  ', 60), 'Ali Veli Demir');
    expect(cleanGiftText('x' * 100, 60).length, 60);
  });
}
