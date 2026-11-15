import 'package:intl/intl.dart';

import '../models/invitation.dart';
import 'date_utils.dart';

/// Davetlilere gönderilecek paylaşım mesajı (UX #10): isimler + etkinlik, tarih/saat ve bağlantı.
/// Metin parçaları davetiye dilindeki ARB anahtarlarından gelir:
///   head  = "{names} – {event}"
///   when  = "📅 {when}"
///   link  = "… {link}"
/// Boş parça (isim ya da tarih yoksa) satır olarak eklenmez.
String buildShareText({
  required String headTpl,
  required String whenTpl,
  required String linkTpl,
  required String names,
  required String event,
  required String when,
  required String link,
}) {
  final lines = <String>[];
  final n = names.trim();
  if (n.isNotEmpty) {
    lines.add(headTpl.replaceAll('{names}', n).replaceAll('{event}', event.trim()));
  } else if (event.trim().isNotEmpty) {
    lines.add(event.trim());
  }
  if (when.trim().isNotEmpty) lines.add(whenTpl.replaceAll('{when}', when.trim()));
  lines.add(linkTpl.replaceAll('{link}', link));
  return lines.join('\n');
}

/// Paylaşım için uzun tarih + saat (ör. "12 Haziran 2027, 19:00"); tarih yoksa boş.
String formatShareWhen(Invitation inv, String lang) {
  final d = parseIsoDate(inv.date);
  if (d == null) return '';
  String day;
  try {
    day = DateFormat.yMMMMd(intlLocale(lang)).format(d);
  } catch (_) {
    day = inv.date;
  }
  final hm = parseHm(inv.time);
  return hm == null ? day : '$day, ${formatHm(hm.$1, hm.$2)}';
}

/// İsimler: çift türlerde "A & B" (ayraç dile göre), tekte tek isim.
String shareNames(Invitation inv, String amp) {
  final a = inv.n1.trim(), b = inv.n2.trim();
  if (!inv.isCouple) return a;
  return [a, b].where((x) => x.isNotEmpty).join(' $amp ');
}

/// Bağlantıyı satır sonunda güzel kırmak için: yalnız '/' ve '&' sonrasına kırılma fırsatı (U+200B) eklenir;
/// alan adı ve kimlik ortadan bölünmez. Yalnız GÖSTERİM içindir; kopyalanan/paylaşılan bağlantı ham kullanılır.
String softBreakUrl(String url) => url.replaceAllMapped(RegExp(r'([/&])(?=.)'), (m) => '${m[1]}\u200B');
