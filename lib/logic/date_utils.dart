import 'package:intl/intl.dart';

/// 'yyyy-MM-dd' → UTC tarih (geçersizse null).
DateTime? parseIsoDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

String isoOf(DateTime d) {
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(d.year, 4)}-${p(d.month)}-${p(d.day)}';
}

/// Önizlemedeki shiftDate: UTC gün kaydırma.
String shiftIsoDate(String iso, int days) {
  final d = parseIsoDate(iso);
  if (d == null) return iso;
  return isoOf(DateTime.utc(d.year, d.month, d.day + days));
}

/// a ile b arasındaki fark (gün, mutlak).
int dayDistance(String a, String b) {
  final x = parseIsoDate(a), y = parseIsoDate(b);
  if (x == null || y == null) return 1 << 30;
  return x.difference(y).inDays.abs();
}

String intlLocale(String lang) {
  switch (lang) {
    case 'en':
      return 'en_GB';
    case 'de':
      return 'de';
    case 'ar':
      return 'ar';
    case 'es':
      return 'es';
    case 'pt':
      return 'pt_BR';
    case 'id':
      return 'id';
    default:
      return 'tr';
  }
}

/// Kısa tarih (ör. 12 Haz 2027).
String formatShortDate(String iso, String lang) {
  final d = parseIsoDate(iso);
  if (d == null) return '';
  try {
    return DateFormat.yMMMd(intlLocale(lang)).format(d);
  } catch (_) {
    return iso;
  }
}

/// 'HH:mm' → (saat, dakika) ya da null.
(int, int)? parseHm(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return (h, mi);
}

String formatHm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
