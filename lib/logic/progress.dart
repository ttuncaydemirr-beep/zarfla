import '../data/catalog.dart';
import '../models/invitation.dart';
import 'date_utils.dart';
import 'validation.dart';

/// Yayın için zorunlu dört bilgi (tarih ve saat tek parça sayılır).
const List<String> kRequiredParts = ['names', 'date', 'venue', 'wa'];

/// Eksik zorunlu bilgiler ([kRequiredParts] sırasıyla; geçmiş tarih de "tarih eksik" sayılır).
List<String> missingRequired(Invitation inv, {DateTime? today}) {
  final e = validateInvitation(inv, today: today);
  return [for (final k in kRequiredParts) if (e.containsKey(k)) k];
}

/// Taslağın hazır olma yüzdesi (0–100, zorunlu bilgilere göre).
int readyPercent(Invitation inv, {DateTime? today}) {
  final missing = missingRequired(inv, today: today).length;
  return ((kRequiredParts.length - missing) * 100 / kRequiredParts.length).round();
}

/// Örnek program adımı: başlangıç saatinden [offsetMin] dakika sonra, metni ARB anahtarı [key].
class SampleStep {
  const SampleStep(this.offsetMin, this.key);

  final int offsetMin;
  final String key;
}

/// Türe göre tek dokunuşla eklenen örnek program (çiftler: karşılama, yemek, pasta; diğerleri: karşılama,
/// program, ikram). Metinler davetiye dilinde ARB'den gelir.
List<SampleStep> sampleProgramFor(String type) => kCoupleTypes.contains(type)
    ? const [SampleStep(0, 'progExWelcome'), SampleStep(60, 'progExDinner'), SampleStep(180, 'progExCake')]
    : const [SampleStep(0, 'progExWelcome'), SampleStep(30, 'progExMain'), SampleStep(90, 'progExTreat')];

/// 'HH:mm' + dakika (gece yarısını geçerse başa sarar). Saat geçersizse 19:00 alınır.
String addMinutesHm(String hm, int minutes) {
  final p = parseHm(hm) ?? (19, 0);
  final total = ((p.$1 * 60 + p.$2 + minutes) % 1440 + 1440) % 1440;
  return formatHm(total ~/ 60, total % 60);
}

/// Etkinliğe kaç gün kaldı (bugün = 0; geçmişse negatif; tarih yoksa null).
int? daysUntil(String iso, DateTime today) {
  final d = parseIsoDate(iso);
  if (d == null) return null;
  return d.difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

/// Yayındaki (süresi dolmamış) davetiyede etkinliğe 0–7 gün kala davetlilere hatırlatma önerilir.
bool shouldSuggestReminder(Invitation inv, DateTime now) {
  if (!inv.isLive || inv.isExpiredAt(now)) return false;
  final n = daysUntil(inv.date, now);
  return n != null && n >= 0 && n <= 7;
}
