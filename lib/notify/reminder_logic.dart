/// Yerel hatırlatma bildirimlerinin SAF mantığı (eklentiden ve Firebase'den bağımsız; birim testli).
///
/// İki hatırlatma türü vardır (sunucu/FCM yok, her şey cihazda zamanlanır):
///  - [ReminderKind.expiry]: ücretsiz davetiyenin 24 saatlik bağlantısı dolmadan [kExpiryLead] önce.
///  - [ReminderKind.draft]: düzenlenip yayınlanmamış taslak için son düzenlemeden ~[kDraftDelay] sonra, taslak başına BİR kez.
library;

import '../models/invitation.dart';

enum ReminderKind { expiry, draft }

/// Ücretsiz bağlantı kapanmadan bu kadar önce haber verilir.
const Duration kExpiryLead = Duration(hours: 3);

/// Yarım taslak için son düzenlemeden bu kadar sonra (bir kez) haber verilir.
const Duration kDraftDelay = Duration(hours: 24);

/// Sessiz saatler (yerel saat): bu aralıkta bildirim gösterilmeyecek şekilde zaman kaydırılır.
/// Taslak hatırlatması sessiz saate düşerse sabah [kDraftWakeHour]:00'a ertelenir; süre hatırlatması
/// (zaman kritik) sessiz saate düşerse akşam [kExpiryEveningHour]:[kExpiryEveningMinute]'e öne alınır
/// (bildirim metni kalan saati gerçek değerle yazar, "3 saat" sabit değildir).
const int kQuietStartMinute = 22 * 60;
const int kQuietEndMinute = 8 * 60;
const int kDraftWakeHour = 9;
const int kExpiryQuietStartMinute = 23 * 60;
const int kExpiryQuietEndMinute = 7 * 60;
const int kExpiryEveningMinute = 22 * 60 + 30;

/// Yeniden zamanlama eşiği: taslakta yeni düzenleme, mevcut hatırlatmayı yalnız bu kadar kaydırıyorsa dokunulmaz.
const Duration kRearmThreshold = Duration(hours: 1);

const int _minMs = 60 * 1000;
const int _hourMs = 3600 * 1000;

/// Epoch ms → yerel saat. Testlerde UTC'yi "yerel" saymak için değiştirilebilir.
typedef LocalClock = DateTime Function(int ms);

DateTime _deviceLocal(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

bool _inWindow(int minuteOfDay, int start, int end) =>
    start > end ? (minuteOfDay >= start || minuteOfDay < end) : (minuteOfDay >= start && minuteOfDay < end);

int _minuteOfDay(DateTime l) => l.hour * 60 + l.minute;

/// [ms]'yi, yerel günün [targetMinute] dakikasına (saniye sıfırlanır) taşır. [forward] true ise ileriye
/// (aynı an dahil değil, en yakın sonraki), false ise geriye (en yakın önceki).
int _moveToMinuteOfDay(int ms, int targetMinute, {required bool forward, LocalClock clock = _deviceLocal}) {
  final l = clock(ms);
  final startOfMinute = ms - l.second * 1000 - l.millisecond;
  final m = _minuteOfDay(l);
  final d = forward ? ((targetMinute - m) % 1440 + 1440) % 1440 : -(((m - targetMinute) % 1440 + 1440) % 1440);
  return startOfMinute + d * _minMs;
}

/// Ücretsiz davetiye süre hatırlatmasının planı: [atMs] gösterim anı, [hoursLeft] o anda kalan tam saat
/// (bildirim metnindeki sayı).
class ExpiryPlan {
  const ExpiryPlan(this.atMs, this.hoursLeft);

  final int atMs;
  final int hoursLeft;

  @override
  bool operator ==(Object other) => other is ExpiryPlan && other.atMs == atMs && other.hoursLeft == hoursLeft;

  @override
  int get hashCode => Object.hash(atMs, hoursLeft);

  @override
  String toString() => 'ExpiryPlan($atMs, $hoursLeft h)';
}

/// Süresi dolmadan [kExpiryLead] önce bildirim planı. Hatırlatma anı geçmişse (ya da süre zaten dolduysa) null.
/// Sessiz saate (23:00–07:00 yerel) düşerse aynı akşam 22:30'a öne alınır; o an geçmişse özgün an kullanılır.
ExpiryPlan? planExpiryReminder(int expiresAtMs, int nowMs, {LocalClock clock = _deviceLocal, bool quietHours = true}) {
  if (expiresAtMs <= nowMs) return null;
  var at = expiresAtMs - kExpiryLead.inMilliseconds;
  if (at <= nowMs + _minMs) return null;
  if (quietHours && _inWindow(_minuteOfDay(clock(at)), kExpiryQuietStartMinute, kExpiryQuietEndMinute)) {
    final earlier = _moveToMinuteOfDay(at, kExpiryEveningMinute, forward: false, clock: clock);
    if (earlier > nowMs + 2 * _minMs) at = earlier;
  }
  final hours = ((expiresAtMs - at) / _hourMs).floor();
  return ExpiryPlan(at, hours < 1 ? 1 : hours);
}

/// Taslak hatırlatması anı: son düzenleme + [kDraftDelay]; sessiz saate (22:00–08:00) düşerse ertesi sabah 09:00.
int planDraftReminder(int lastEditMs, {LocalClock clock = _deviceLocal, bool quietHours = true}) {
  final at = lastEditMs + kDraftDelay.inMilliseconds;
  if (quietHours && _inWindow(_minuteOfDay(clock(at)), kQuietStartMinute, kQuietEndMinute)) {
    return _moveToMinuteOfDay(at, kDraftWakeHour * 60, forward: true, clock: clock);
  }
  return at;
}

/// Taslakta kullanıcının girdiği gerçek içerik var mı? (Örnek mesaj otomatik dolduğundan yalnız elle girilenler sayılır.)
/// Boş taslak (yalnız tür/tasarım seçilmiş) için hatırlatma gönderilmez.
bool draftHasUserContent(Invitation inv) =>
    inv.n1.trim().isNotEmpty ||
    inv.n2.trim().isNotEmpty ||
    inv.host.trim().isNotEmpty ||
    inv.date.trim().isNotEmpty ||
    inv.venue.trim().isNotEmpty ||
    inv.wa.trim().isNotEmpty ||
    inv.cover.isNotEmpty ||
    inv.photos.isNotEmpty;

/// Taslağın "düzenlendi mi" parmak izi: kullanıcıya ait alanlar (zaman, durum ve bulut alanları hariç).
String draftFingerprint(Invitation inv) {
  final j = inv.toJson();
  for (final k in const ['created', 'status', 'plan', 'expiresAt', 'cloudId', 'cloudFiles', 'nameEditsLeft', 'dateEditsLeft', 'originalDate']) {
    j.remove(k);
  }
  return j.toString();
}

/// Taslak bildirim metninin ARB anahtarı: hazır yüzdesine göre (yüzde 0 iken "%0 hazır" yazılmaz).
String draftBodyKey(int pct) => pct >= 100 ? 'notifDraftBodyReady' : (pct > 0 ? 'notifDraftBody' : 'notifDraftBodyStart');

/// Bildirim kimliği (Android int): tür + davetiye kimliğinden kararlı, pozitif 31 bit FNV-1a.
int reminderNotificationId(ReminderKind kind, String invId) {
  var h = 0x811c9dc5;
  for (final c in '${kind.name}:$invId'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  final id = h & 0x7fffffff;
  return id == 0 ? 1 : id;
}

/// Zamanlanmış bir hatırlatmanın kayıt anahtarı: "x:<kimlik>" (süre) ya da "d:<kimlik>" (taslak).
String reminderKey(ReminderKind kind, String invId) => '${kind == ReminderKind.expiry ? 'x' : 'd'}:$invId';

/// Bildirim yükü (dokununca açılacak davetiye).
class ReminderPayload {
  const ReminderPayload(this.kind, this.invId);

  final ReminderKind kind;
  final String invId;

  String encode() => reminderKey(kind, invId);

  /// Geçersiz/boş/yabancı yük için null.
  static ReminderPayload? parse(String? raw) {
    if (raw == null || raw.length < 3 || raw[1] != ':') return null;
    final id = raw.substring(2);
    if (id.isEmpty) return null;
    switch (raw[0]) {
      case 'x':
        return ReminderPayload(ReminderKind.expiry, id);
      case 'd':
        return ReminderPayload(ReminderKind.draft, id);
    }
    return null;
  }
}

/// İstenen bir hatırlatma.
class ReminderSpec {
  const ReminderSpec({required this.kind, required this.invId, required this.atMs, required this.extra});

  final ReminderKind kind;
  final String invId;
  final int atMs;

  /// Süre: kalan saat · taslak: hazır yüzdesi (metin yer tutucusu {n}).
  final int extra;

  String get key => reminderKey(kind, invId);
}

/// Cihazda zamanlanmış hatırlatmanın kaydı. [sig] metni etkileyen her şeyi (dil, sayı) taşır.
class ScheduledReminder {
  const ScheduledReminder({required this.atMs, required this.sig});

  final int atMs;
  final String sig;

  Map<String, Object> toJson() => {'at': atMs, 'sig': sig};

  static ScheduledReminder? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = j['at'], sig = j['sig'];
    if (at is! int || sig is! String) return null;
    return ScheduledReminder(atMs: at, sig: sig);
  }
}

String reminderSig(ReminderSpec s, String lang) => '$lang|${s.extra}';

/// Fark: hangi kayıtlar iptal edilecek, hangileri (yeniden) zamanlanacak.
class ReminderDiff {
  const ReminderDiff({required this.cancel, required this.schedule});

  final List<String> cancel;
  final List<ReminderSpec> schedule;
}

/// [scheduled] (cihazdaki kayıt) ile [desired] (olması gereken) arasındaki fark.
/// Aynı anahtar, aynı an ve aynı imzayla zaten zamanlıysa dokunulmaz.
ReminderDiff diffReminders({
  required Map<String, ScheduledReminder> scheduled,
  required Map<String, ReminderSpec> desired,
  required String lang,
}) {
  final cancel = <String>[];
  final schedule = <ReminderSpec>[];
  for (final k in scheduled.keys) {
    if (!desired.containsKey(k)) cancel.add(k);
  }
  for (final e in desired.entries) {
    final cur = scheduled[e.key];
    if (cur == null || cur.atMs != e.value.atMs || cur.sig != reminderSig(e.value, lang)) schedule.add(e.value);
  }
  return ReminderDiff(cancel: cancel, schedule: schedule);
}

/// Yeni düzenleme sonrası taslak hatırlatma anı: mevcut kayıt varsa ve yeni an ondan [kRearmThreshold]'dan az
/// ileriyse mevcut an korunur (her tuş vuruşunda yeniden zamanlamayı önler).
int stableDraftAt({required int? currentAtMs, required int plannedAtMs}) {
  if (currentAtMs != null && plannedAtMs >= currentAtMs && plannedAtMs - currentAtMs < kRearmThreshold.inMilliseconds) {
    return currentAtMs;
  }
  return plannedAtMs;
}
