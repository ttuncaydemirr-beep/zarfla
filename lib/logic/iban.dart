/// IBAN doğrulama ve biçimlendirme (saf Dart). Ülke uzunluk tablosu + mod-97 sağlama toplamı.
/// Davetli sayfasındaki (assets/invite/invite.html) JS doğrulayıcısıyla aynı kuralları uygular.

const int kGiftHolderMax = 60;
const int kGiftBankMax = 60;

/// IBAN kayıt defterine göre ülke → toplam uzunluk.
const Map<String, int> kIbanLengths = {
  'AD': 24, 'AE': 23, 'AL': 28, 'AT': 20, 'AZ': 28, 'BA': 20, 'BE': 16, 'BG': 22, 'BH': 22, 'BI': 27,
  'BR': 29, 'BY': 28, 'CH': 21, 'CR': 22, 'CY': 28, 'CZ': 24, 'DE': 22, 'DJ': 27, 'DK': 18, 'DO': 28,
  'EE': 20, 'EG': 29, 'ES': 24, 'FI': 18, 'FK': 18, 'FO': 18, 'FR': 27, 'GB': 22, 'GE': 22, 'GI': 23,
  'GL': 18, 'GR': 27, 'GT': 28, 'HR': 21, 'HU': 28, 'IE': 22, 'IL': 23, 'IQ': 23, 'IS': 26, 'IT': 27,
  'JO': 30, 'KW': 30, 'KZ': 20, 'LB': 28, 'LC': 32, 'LI': 21, 'LT': 20, 'LU': 20, 'LV': 21, 'LY': 25,
  'MC': 27, 'MD': 24, 'ME': 22, 'MK': 19, 'MN': 20, 'MR': 27, 'MT': 31, 'MU': 30, 'NL': 18, 'NO': 15,
  'OM': 23, 'PK': 24, 'PL': 28, 'PS': 29, 'PT': 25, 'QA': 29, 'RO': 24, 'RS': 22, 'RU': 33, 'SA': 24,
  'SC': 31, 'SD': 18, 'SE': 24, 'SI': 19, 'SK': 24, 'SM': 27, 'SO': 23, 'ST': 25, 'SV': 28, 'TL': 23,
  'TN': 24, 'TR': 26, 'UA': 29, 'VA': 22, 'VG': 24, 'XK': 20, 'YE': 30,
};

/// Boşluk, tire ve nokta atılır; büyük harfe çevrilir. Saklanan biçim budur.
String normalizeIban(String s) => s.replaceAll(RegExp(r'[\s\-.]'), '').toUpperCase();

/// Biçim + ülke uzunluğu + mod-97 (== 1).
bool isValidIban(String input) {
  final v = normalizeIban(input);
  if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$').hasMatch(v)) return false;
  final len = kIbanLengths[v.substring(0, 2)];
  if (len == null || v.length != len) return false;
  final t = v.substring(4) + v.substring(0, 4);
  var r = 0;
  for (final c in t.codeUnits) {
    if (c >= 48 && c <= 57) {
      r = (r * 10 + (c - 48)) % 97;
    } else {
      r = (r * 100 + (c - 55)) % 97; // A=10 … Z=35 (iki basamak)
    }
  }
  return r == 1;
}

/// 4'lü gruplar: "TR33 0006 1005 …".
String formatIban(String input) {
  final v = normalizeIban(input);
  final b = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    if (i > 0 && i % 4 == 0) b.write(' ');
    b.write(v[i]);
  }
  return b.toString();
}

/// Ad: kontrol karakterleri atılır, kırpılır, en çok [kGiftHolderMax] karakter.
String cleanGiftText(String s, int max) {
  final t = s.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();
  return t.length > max ? t.substring(0, max).trim() : t;
}
