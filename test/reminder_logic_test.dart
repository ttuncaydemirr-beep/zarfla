import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/notify/reminder_logic.dart';

// Testlerde UTC "yerel saat" sayılır: sessiz saat hesabı makinenin saat diliminden bağımsız kalır.
DateTime utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
int at(int d, int h, [int m = 0]) => DateTime.utc(2026, 11, d, h, m).millisecondsSinceEpoch;
const int hour = 3600 * 1000;

Invitation inv({String n1 = '', String status = 'draft', String? plan}) =>
    Invitation(id: 'a1', type: 'dugun', theme: 'papatya', lang: 'tr', created: 0, n1: n1, status: status, plan: plan);

void main() {
  group('süre hatırlatması (ücretsiz bağlantı)', () {
    test('süre dolmadan 3 saat önce, kalan saat 3', () {
      final now = at(17, 12);
      final exp = now + 24 * hour; // yayın + 24 saat
      final p = planExpiryReminder(exp, now, clock: utc)!;
      expect(p.atMs, exp - 3 * hour);
      expect(p.hoursLeft, 3);
      expect(p.atMs, at(18, 9));
    });

    test('hatırlatma anı geçmişse ya da süre dolmuşsa null', () {
      final now = at(17, 12);
      expect(planExpiryReminder(now + 2 * hour, now, clock: utc), isNull); // an geçmişte
      expect(planExpiryReminder(now + 3 * hour, now, clock: utc), isNull); // an = şimdi
      expect(planExpiryReminder(now - hour, now, clock: utc), isNull); // süre dolmuş
    });

    test('sessiz saate (23:00-07:00) düşerse aynı akşam 22:30\'a öne alınır, metin gerçek saati yazar', () {
      final now = at(17, 5); // 05:00 yayın → süre ertesi gün 05:00 → özgün an 02:00 (sessiz)
      final exp = now + 24 * hour;
      final p = planExpiryReminder(exp, now, clock: utc)!;
      expect(p.atMs, at(17, 22, 30));
      expect(p.hoursLeft, 6); // 22:30 → 05:00 = 6,5 saat → 6
    });

    test('öne alınan an geçmişteyse özgün an korunur', () {
      final exp = at(18, 5);
      final now = at(17, 23, 59); // 22:30 çoktan geçti
      final p = planExpiryReminder(exp, now, clock: utc)!;
      expect(p.atMs, exp - 3 * hour);
      expect(p.hoursLeft, 3);
    });

    test('sessiz saat kapatılırsa kaydırma yok', () {
      final now = at(17, 5);
      final exp = now + 24 * hour;
      expect(planExpiryReminder(exp, now, clock: utc, quietHours: false)!.atMs, exp - 3 * hour);
    });

    test('sessiz saatin dışındaki sınırlar: 07:00 ve 22:59 kaydırılmaz', () {
      final now = at(17, 4);
      // özgün an 07:00 (sessiz bitişi): kaydırılmaz
      expect(planExpiryReminder(at(17, 10), now, clock: utc)!.atMs, at(17, 7));
      // özgün an 22:59 sessiz değil
      expect(planExpiryReminder(at(18, 1, 59), at(17, 12), clock: utc)!.atMs, at(17, 22, 59));
    });
  });

  group('taslak hatırlatması', () {
    test('son düzenleme + 24 saat; gündüzse kaydırılmaz', () {
      expect(planDraftReminder(at(17, 12), clock: utc), at(18, 12));
    });

    test('gece 22:00-08:00 arasına düşerse ertesi sabah 09:00', () {
      expect(planDraftReminder(at(17, 23), clock: utc), at(19, 9)); // 23:00 → ertesi gün 23:00 → o sabah değil, sonraki sabah
      expect(planDraftReminder(at(17, 3), clock: utc), at(18, 9)); // 03:00 → ertesi gün 03:00 → aynı gün 09:00
      expect(planDraftReminder(at(17, 22), clock: utc), at(19, 9));
      expect(planDraftReminder(at(17, 8), clock: utc), at(18, 8)); // 08:00 sessiz değil
      expect(planDraftReminder(at(17, 21, 59), clock: utc), at(18, 21, 59));
    });

    test('sessiz saat kapalıysa tam 24 saat', () {
      expect(planDraftReminder(at(17, 23), clock: utc, quietHours: false), at(18, 23));
    });

    test('stableDraftAt: küçük kaymada mevcut an korunur, büyükte yenisi alınır', () {
      final cur = at(18, 12);
      expect(stableDraftAt(currentAtMs: cur, plannedAtMs: cur + 30 * 60 * 1000), cur);
      expect(stableDraftAt(currentAtMs: cur, plannedAtMs: cur + 2 * hour), cur + 2 * hour);
      expect(stableDraftAt(currentAtMs: null, plannedAtMs: cur), cur);
      expect(stableDraftAt(currentAtMs: cur, plannedAtMs: cur - hour), cur - hour); // öne alma her zaman uygulanır
    });
  });

  group('taslak içeriği ve parmak izi', () {
    test('boş taslak (yalnız tür/tasarım) içerik sayılmaz; isim/tarih/mekân/WhatsApp/fotoğraf sayılır', () {
      expect(draftHasUserContent(inv()), isFalse);
      expect(draftHasUserContent(inv(n1: '  ')), isFalse);
      expect(draftHasUserContent(inv(n1: 'Ali')), isTrue);
      expect((inv()..venue = 'Salon').let(draftHasUserContent), isTrue);
      expect((inv()..date = '2027-01-01').let(draftHasUserContent), isTrue);
      expect((inv()..wa = '905321234567').let(draftHasUserContent), isTrue);
      expect((inv()..photos.add('p.jpg')).let(draftHasUserContent), isTrue);
    });

    test('parmak izi: düzenleyince değişir; durum/bulut alanları değişince değişmez', () {
      final a = inv(n1: 'Ali');
      final f0 = draftFingerprint(a);
      expect(draftFingerprint(a), f0);
      a.status = 'live';
      a.plan = 'free';
      a.cloudId = 'x';
      a.expiresAt = 5;
      expect(draftFingerprint(a), f0);
      a.n1 = 'Ali B';
      expect(draftFingerprint(a), isNot(f0));
    });
  });

  test('taslak metin anahtarı yüzdeye göre', () {
    expect(draftBodyKey(0), 'notifDraftBodyStart');
    expect(draftBodyKey(25), 'notifDraftBody');
    expect(draftBodyKey(75), 'notifDraftBody');
    expect(draftBodyKey(100), 'notifDraftBodyReady');
  });

  group('kimlik, yük, fark', () {
    test('bildirim kimliği kararlı, pozitif, türe göre farklı', () {
      final a = reminderNotificationId(ReminderKind.expiry, 'abc123');
      expect(reminderNotificationId(ReminderKind.expiry, 'abc123'), a);
      expect(a, greaterThan(0));
      expect(a, lessThanOrEqualTo(0x7fffffff));
      expect(reminderNotificationId(ReminderKind.draft, 'abc123'), isNot(a));
      expect(reminderNotificationId(ReminderKind.expiry, 'abc124'), isNot(a));
    });

    test('yük: gidiş-dönüş ve geçersiz girdiler', () {
      for (final k in ReminderKind.values) {
        final p = ReminderPayload.parse(ReminderPayload(k, 'id_9').encode())!;
        expect(p.kind, k);
        expect(p.invId, 'id_9');
      }
      expect(ReminderPayload.parse(null), isNull);
      expect(ReminderPayload.parse(''), isNull);
      expect(ReminderPayload.parse('x:'), isNull);
      expect(ReminderPayload.parse('z:abc'), isNull);
      expect(ReminderPayload.parse('xabc'), isNull);
      expect(ReminderPayload.parse('x:a:b')!.invId, 'a:b');
    });

    ReminderSpec spec(String id, int atMs, [int extra = 3, ReminderKind k = ReminderKind.expiry]) =>
        ReminderSpec(kind: k, invId: id, atMs: atMs, extra: extra);

    test('fark: yeni, değişmeyen, değişen ve kalkan', () {
      final keep = spec('a', 100);
      final chg = spec('b', 200);
      final add = spec('c', 300);
      final d = diffReminders(
        scheduled: {
          keep.key: ScheduledReminder(atMs: 100, sig: reminderSig(keep, 'tr')),
          chg.key: ScheduledReminder(atMs: 150, sig: reminderSig(chg, 'tr')), // an değişti
          'd:gone': const ScheduledReminder(atMs: 1, sig: 'tr|0'),
        },
        desired: {keep.key: keep, chg.key: chg, add.key: add},
        lang: 'tr',
      );
      expect(d.cancel, ['d:gone']);
      expect(d.schedule.map((e) => e.invId).toSet(), {'b', 'c'});
    });

    test('fark: dil değişince yeniden zamanlanır', () {
      final s = spec('a', 100);
      final d = diffReminders(scheduled: {s.key: ScheduledReminder(atMs: 100, sig: reminderSig(s, 'tr'))}, desired: {s.key: s}, lang: 'de');
      expect(d.schedule, hasLength(1));
      expect(d.cancel, isEmpty);
    });
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
