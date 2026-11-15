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

/// Ülke adları arayüz dilinde (seçici ve öneri metni için). Liste dışındaki dillerde [Country.name] kullanılır.
const Map<String, Map<String, String>> kCountryNamesByLang = {
  'tr': {
    'TR': 'Türkiye', 'DE': 'Almanya', 'AT': 'Avusturya', 'CH': 'İsviçre', 'NL': 'Hollanda', 'BE': 'Belçika', //
    'FR': 'Fransa', 'GB': 'Birleşik Krallık', 'US': 'ABD / Kanada', 'SA': 'Suudi Arabistan', 'AE': 'BAE', //
    'QA': 'Katar', 'KW': 'Kuveyt', 'BH': 'Bahreyn', 'OM': 'Umman', 'JO': 'Ürdün', 'EG': 'Mısır', //
    'AZ': 'Azerbaycan', 'RU': 'Rusya / Kazakistan', 'GR': 'Yunanistan', 'BG': 'Bulgaristan', 'SE': 'İsveç', //
    'DK': 'Danimarka', 'NO': 'Norveç', 'IT': 'İtalya', 'ES': 'İspanya', 'AU': 'Avustralya',
  },
  'en': {
    'TR': 'Türkiye', 'DE': 'Germany', 'AT': 'Austria', 'CH': 'Switzerland', 'NL': 'Netherlands', 'BE': 'Belgium', //
    'FR': 'France', 'GB': 'United Kingdom', 'US': 'USA / Canada', 'SA': 'Saudi Arabia', 'AE': 'UAE', //
    'QA': 'Qatar', 'KW': 'Kuwait', 'BH': 'Bahrain', 'OM': 'Oman', 'JO': 'Jordan', 'EG': 'Egypt', //
    'AZ': 'Azerbaijan', 'RU': 'Russia / Kazakhstan', 'GR': 'Greece', 'BG': 'Bulgaria', 'SE': 'Sweden', //
    'DK': 'Denmark', 'NO': 'Norway', 'IT': 'Italy', 'ES': 'Spain', 'AU': 'Australia',
  },
  'de': {
    'TR': 'Türkei', 'DE': 'Deutschland', 'AT': 'Österreich', 'CH': 'Schweiz', 'NL': 'Niederlande', 'BE': 'Belgien', //
    'FR': 'Frankreich', 'GB': 'Vereinigtes Königreich', 'US': 'USA / Kanada', 'SA': 'Saudi-Arabien', 'AE': 'VAE', //
    'QA': 'Katar', 'KW': 'Kuwait', 'BH': 'Bahrain', 'OM': 'Oman', 'JO': 'Jordanien', 'EG': 'Ägypten', //
    'AZ': 'Aserbaidschan', 'RU': 'Russland / Kasachstan', 'GR': 'Griechenland', 'BG': 'Bulgarien', 'SE': 'Schweden', //
    'DK': 'Dänemark', 'NO': 'Norwegen', 'IT': 'Italien', 'ES': 'Spanien', 'AU': 'Australien',
  },
  'ar': {
    'TR': 'تركيا', 'DE': 'ألمانيا', 'AT': 'النمسا', 'CH': 'سويسرا', 'NL': 'هولندا', 'BE': 'بلجيكا', //
    'FR': 'فرنسا', 'GB': 'المملكة المتحدة', 'US': 'الولايات المتحدة / كندا', 'SA': 'السعودية', 'AE': 'الإمارات', //
    'QA': 'قطر', 'KW': 'الكويت', 'BH': 'البحرين', 'OM': 'عُمان', 'JO': 'الأردن', 'EG': 'مصر', //
    'AZ': 'أذربيجان', 'RU': 'روسيا / كازاخستان', 'GR': 'اليونان', 'BG': 'بلغاريا', 'SE': 'السويد', //
    'DK': 'الدنمارك', 'NO': 'النرويج', 'IT': 'إيطاليا', 'ES': 'إسبانيا', 'AU': 'أستراليا',
  },
};

/// Çevirme koduna göre ülke (yoksa null).
Country? countryByDial(String dial) {
  for (final c in kCountries) {
    if (c.dial == dial) return c;
  }
  return null;
}

/// Ülkenin arayüz dilindeki adı.
String countryNameIn(Country c, String lang) => kCountryNamesByLang[lang]?[c.iso] ?? c.name;
