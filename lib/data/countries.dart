/// WhatsApp numarası için ülke kodu listesi (bayrak + çevirme kodu + ülkenin kendi dilindeki adı).
/// Her çevirme kodu bir kez geçer (+1 ABD/Kanada, +7 Rusya/Kazakistan tek satır).
class Country {
  const Country(this.iso, this.dial, this.name);

  /// Bayrak için ISO 3166 kodu (iki harf).
  final String iso;

  /// Artı işaretsiz çevirme kodu, ör. "90".
  final String dial;

  /// Ülkenin yerel adı (arayüz diline göre değişmez).
  final String name;

  /// Bayrak emojisi (iki bölgesel gösterge sembolü).
  String get flag => String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

const List<Country> kCountries = [
  Country('TR', '90', 'Türkiye'),
  Country('DE', '49', 'Deutschland'),
  Country('AT', '43', 'Österreich'),
  Country('CH', '41', 'Schweiz'),
  Country('NL', '31', 'Nederland'),
  Country('BE', '32', 'België'),
  Country('FR', '33', 'France'),
  Country('GB', '44', 'United Kingdom'),
  Country('US', '1', 'USA / Canada'),
  Country('SA', '966', 'السعودية'),
  Country('AE', '971', 'الإمارات'),
  Country('QA', '974', 'قطر'),
  Country('KW', '965', 'الكويت'),
  Country('BH', '973', 'البحرين'),
  Country('OM', '968', 'عُمان'),
  Country('JO', '962', 'الأردن'),
  Country('EG', '20', 'مصر'),
  Country('AZ', '994', 'Azərbaycan'),
  Country('RU', '7', 'Россия / Казахстан'),
  Country('GR', '30', 'Ελλάδα'),
  Country('BG', '359', 'България'),
  Country('SE', '46', 'Sverige'),
  Country('DK', '45', 'Danmark'),
  Country('NO', '47', 'Norge'),
  Country('IT', '39', 'Italia'),
  Country('ES', '34', 'España'),
  Country('AU', '61', 'Australia'),
];

/// ISO ülke kodu → çevirme kodu (liste dışındaki ülkeler için null). KZ → +7, CA → +1.
const Map<String, String> kIsoToDial = {
  'KZ': '7',
  'CA': '1',
};

/// Dil → varsayılan çevirme kodu (cihaz bölgesi bilinmiyorsa).
const Map<String, String> kLangDefaultDial = {
  'tr': '90',
  'de': '49',
  'ar': '966',
  'en': '44',
};
