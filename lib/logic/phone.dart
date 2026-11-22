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

/// ISO ülke kodu → listedeki çevirme kodu (yoksa null).
String? dialForCountry(String? iso) {
  final cc = (iso ?? '').toUpperCase();
  if (cc.isEmpty) return null;
  final mapped = kIsoToDial[cc];
  if (mapped != null) return mapped;
  for (final c in kCountries) {
    if (c.iso == cc) return c.dial;
  }
  return null;
}

/// Varsayılan ülke kodu: önce davetiye dilinin ülkesi (tr→+90, de→+49, ar→+966, en→+44, es→+52, pt→+55, id→+62), dil eşlemesi
/// yoksa cihazın ülkesi, en sonda +90. Cihaz bölgesi farklıysa seçici [deviceDialHint] ile öne çıkarılır.
String defaultDial({String? deviceCountry, String lang = 'tr'}) {
  return kLangDefaultDial[lang] ?? dialForCountry(deviceCountry) ?? '90';
}

/// Cihaz bölgesinin çevirme kodu seçili koddan farklıysa o kod (seçici öne çıkarılır ve tek dokunuşla
/// değiştirme önerilir), aynıysa ya da bölge bilinmiyorsa null.
String? deviceDialHint({String? deviceCountry, required String currentDial}) {
  final d = dialForCountry(deviceCountry);
  if (d == null || d == currentDial) return null;
  return d;
}

/// Ülkelerin cep telefonu numarası kalıpları (ülke kodsuz, başında 0 olmadan). Yalnız birbirine karışmayan,
/// diasporada en sık görülen üç kalıp: Türkiye 5XX XXX XX XX, Almanya 15x/16x/17x, Birleşik Krallık 7XXX.
const Map<String, String> kMobilePatterns = {
  '90': r'^5\d{9}$',
  '49': r'^1[5-7]\d{8,9}$',
  '44': r'^7\d{9}$',
};

/// Yazılan yerel numara seçili ülkeden çok başka bir ülkenin cep numarasına benziyorsa o ülkenin kodu.
/// Seçili ülkenin kendi kalıbına uyuyorsa, numara boşsa ya da "diğer" seçiliyse null (öneri yok).
String? suggestDial(String local, String currentDial) {
  if (currentDial.isEmpty) return null;
  final d = _stripLeadingZeros(_digits(local));
  if (d.isEmpty) return null;
  final own = kMobilePatterns[currentDial];
  if (own != null && RegExp(own).hasMatch(d)) return null;
  for (final e in kMobilePatterns.entries) {
    if (e.key != currentDial && RegExp(e.value).hasMatch(d)) return e.key;
  }
  return null;
}

/// Yerel numarayı okunur gruplar (yalnız gösterim): Türkiye 3-3-2-2, diğerleri 3'erli (son grup en az 2 rakam).
String formatLocalNumber(String dial, String local) {
  final d = _digits(local);
  if (d.isEmpty) return '';
  if (dial == '90' && d.length == 10) {
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8)}';
  }
  final g = <String>[];
  for (var i = 0; i < d.length; i += 3) {
    g.add(d.substring(i, i + 3 > d.length ? d.length : i + 3));
  }
  if (g.length > 1 && g.last.length < 2) {
    final last = g.removeLast();
    g[g.length - 1] = g.last + last;
  }
  return g.join(' ');
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
