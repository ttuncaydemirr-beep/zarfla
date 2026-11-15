import '../data/countries.dart';

/// Ülke kodu + yerel numara (ikisi de yalnız rakam; [dial] boş olabilir: "diğer", numara uluslararası yazılmış).
class PhoneParts {
  const PhoneParts(this.dial, this.local);

  final String dial;
  final String local;

  @override
  String toString() => 'PhoneParts($dial, $local)';
}

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

String _stripLeadingZeros(String s) => s.replaceFirst(RegExp(r'^0+'), '');

/// Rakam dizisinin başındaki en uzun ülke kodu (yoksa null). Boş kalan yerel kısım da kabul edilir.
String? matchDial(String digits) {
  String? best;
  for (final c in kCountries) {
    if (digits.startsWith(c.dial) && (best == null || c.dial.length > best.length)) best = c.dial;
  }
  return best;
}

/// Varsayılan ülke kodu: önce cihazın ülkesi (ISO), sonra dil, en sonda +90.
String defaultDial({String? deviceCountry, String lang = 'tr'}) {
  final cc = (deviceCountry ?? '').toUpperCase();
  if (cc.isNotEmpty) {
    final mapped = kIsoToDial[cc];
    if (mapped != null) return mapped;
    for (final c in kCountries) {
      if (c.iso == cc) return c.dial;
    }
  }
  return kLangDefaultDial[lang] ?? '90';
}

/// Kayıtlı değeri (örn. "905321234567", "+49 151 2345678") seçici + yerel numaraya ayırır.
/// Ülke kodu bulunamazsa: 0 ile başlıyorsa yerel numara sayılır ([fallbackDial] ile); aksi halde dial boş ("diğer") kalır
/// ve numara olduğu gibi korunur.
PhoneParts parsePhone(String stored, {required String fallbackDial}) {
  var d = _digits(stored);
  if (d.isEmpty) return PhoneParts(fallbackDial, '');
  if (d.startsWith('00')) {
    d = _stripLeadingZeros(d);
  } else if (d.startsWith('0')) {
    return PhoneParts(fallbackDial, _stripLeadingZeros(d));
  }
  final m = matchDial(d);
  if (m == null) return PhoneParts('', d);
  return PhoneParts(m, _stripLeadingZeros(d.substring(m.length)));
}

/// Kullanıcının numara alanına yazdığı/yapıştırdığı metin.
/// Başta "+" veya "00" varsa uluslararası numara sayılır: ülke otomatik seçilir. Başta tek "0" (Türkiye/Almanya vb. ön eki) atılır.
/// Dönen [changed] true ise alan metninin [PhoneParts.local] ile değiştirilmesi gerekir; false ise kullanıcının yazdığı olduğu gibi kalır.
({PhoneParts parts, bool changed}) normalizeLocalInput(String raw, String currentDial) {
  final t = raw.trim();
  var d = _digits(t);
  final intl = t.startsWith('+') || d.startsWith('00');
  if (intl) {
    d = _stripLeadingZeros(d);
    final m = matchDial(d);
    if (m != null) {
      return (parts: PhoneParts(m, _stripLeadingZeros(d.substring(m.length))), changed: true);
    }
    // Kod henüz yazılıyor olabilir ("+3", "+35"): metne dokunma.
    if (d.length < 3) return (parts: PhoneParts(currentDial, d), changed: false);
    // Listede olmayan ülke: "diğer" modu, numara uluslararası haliyle kalır.
    return (parts: PhoneParts('', d), changed: true);
  }
  if (d.startsWith('0')) {
    return (parts: PhoneParts(currentDial, _stripLeadingZeros(d)), changed: true);
  }
  return (parts: PhoneParts(currentDial, d), changed: false);
}

/// Saklanan değer: ülke kodu + yerel rakamlar, artı ve boşluk yok (örn. "905321234567").
/// invite.html bunu `replace(/\D/g, "")` ile okur. Yerel kısım boşsa boş döner (zorunlu alan doğrulaması yakalar).
String composeWa(String dial, String local) {
  final l = _stripLeadingZeros(_digits(local));
  return l.isEmpty ? '' : dial + l;
}

/// Yerel numara uzunluk kontrolü: 6–14 rakam.
bool isValidLocalNumber(String local) {
  final n = _digits(local).length;
  return n >= 6 && n <= 14;
}
