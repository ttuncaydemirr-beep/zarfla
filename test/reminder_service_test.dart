import 'package:flutter_test/flutter_test.dart';
import 'package:zarfla/models/invitation.dart';
import 'package:zarfla/notify/reminder_logic.dart';
import 'package:zarfla/notify/reminder_platform.dart';
import 'package:zarfla/notify/reminder_service.dart';
import 'package:zarfla/notify/reminder_store.dart';

DateTime utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
int at(int d, int h, [int m = 0]) => DateTime.utc(2026, 11, d, h, m).millisecondsSinceEpoch;
const int hour = 3600 * 1000;

class Sched {
  Sched(this.id, this.title, this.body, this.atMs, this.payload);
  final int id;
  final String title, body, payload;
  final int atMs;
}

class FakePlatform implements ReminderPlatform {
  final Map<int, Sched> scheduled = {};
  final List<int> cancelled = [];
  int scheduleCalls = 0;
  bool enabled = true;
  bool grant = true;
  int permissionRequests = 0;
  String? launchPayload;
  void Function(String?)? tap;
  bool failSchedule = false;

  @override
  Future<String?> init(void Function(String? payload) onTap) async {
    tap = onTap;
    return launchPayload;
  }

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    enabled = grant;
    return grant;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
    required String payload,
    required String channelName,
    required String channelDesc,
  }) async {
    if (failSchedule) throw StateError('boom');
    scheduleCalls++;
    scheduled[id] = Sched(id, title, body, atMs, payload);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class Rig {
  Rig({ReminderState? initial, int? start}) : nowMs = start ?? at(17, 12) {
    store = MemoryReminderStore(initial);
    r = Reminders(now: () => nowMs, clock: utc);
  }

  int nowMs;
  late final MemoryReminderStore store;
  late final Reminders r;
  final FakePlatform p = FakePlatform();
  final List<Invitation> invs = [];
  String lang = 'tr';
  final List<ReminderPayload> opened = [];

  Future<void> start() => r.start(
        platform: p,
        store: store,
        host: ReminderHost(
          invitations: () => invs,
          lang: () => lang,
          text: (l, k, a) => '$l:$k${a.isEmpty ? '' : a.toString()}',
          onOpen: opened.add,
        ),
      );

  Future<void> sync() async {
    r.sync();
    await r.settled();
  }

  Invitation freeLive(String id, int expiresAt) => Invitation(
        id: id,
        type: 'dugun',
        theme: 'papatya',
        lang: 'tr',
        created: 0,
        n1: 'Ali',
        status: 'live',
        plan: 'free',
        cloudId: 'C$id',
        expiresAt: expiresAt,
      );

  Invitation draft(String id, {String n1 = ''}) => Invitation(id: id, type: 'dugun', theme: 'papatya', lang: 'tr', created: 0, n1: n1);

  int xid(String id) => reminderNotificationId(ReminderKind.expiry, id);
  int did(String id) => reminderNotificationId(ReminderKind.draft, id);
}

void main() {
  group('süre hatırlatması', () {
    test('ücretsiz yayın: 3 saat önceye zamanlanır; metin ve yük doğru', () async {
      final g = Rig();
      await g.start();
      g.invs.add(g.freeLive('a', g.nowMs + 24 * hour));
      await g.sync();
      final s = g.p.scheduled[g.xid('a')]!;
      expect(s.atMs, g.nowMs + 21 * hour);
      expect(s.title, 'tr:notifExpiryTitle{n: 3}');
      expect(s.body, 'tr:notifExpiryBody');
      expect(ReminderPayload.parse(s.payload)!.kind, ReminderKind.expiry);
      expect(ReminderPayload.parse(s.payload)!.invId, 'a');
    });

    test('aynı durumda tekrar eşitleme yeniden zamanlamaz (tuş vuruşu başına çağrı yok)', () async {
      final g = Rig();
      await g.start();
      g.invs.add(g.freeLive('a', g.nowMs + 24 * hour));
      await g.sync();
      await g.sync();
      await g.sync();
      expect(g.p.scheduleCalls, 1);
    });

    test('ödeme (premium) iptal eder', () async {
      final g = Rig();
      await g.start();
      final i = g.freeLive('a', g.nowMs + 24 * hour);
      g.invs.add(i);
      await g.sync();
      i
        ..plan = 'premium'
        ..expiresAt = g.nowMs + 365 * 24 * hour;
      await g.sync();
      expect(g.p.scheduled, isEmpty);
      expect(g.p.cancelled, [g.xid('a')]);
    });

    test('silme iptal eder', () async {
      final g = Rig();
      await g.start();
      g.invs.add(g.freeLive('a', g.nowMs + 24 * hour));
      await g.sync();
      g.invs.clear();
      await g.sync();
      expect(g.p.scheduled, isEmpty);
    });

    test('yayında olmayan, süresi dolmuş ya da bulut kimliği olmayan için zamanlanmaz', () async {
      final g = Rig();
      await g.start();
      g.invs.add(g.freeLive('old', g.nowMs - hour));
      g.invs.add(g.freeLive('soon', g.nowMs + 2 * hour)); // hatırlatma anı geçmiş
      g.invs.add(g.freeLive('nocloud', g.nowMs + 24 * hour)..cloudId = null);
      await g.sync();
      expect(g.p.scheduled, isEmpty);
    });

    test('dil değişince yeni dilde yeniden zamanlanır', () async {
      final g = Rig();
      await g.start();
      g.invs.add(g.freeLive('a', g.nowMs + 24 * hour));
      await g.sync();
      g.lang = 'de';
      await g.sync();
      expect(g.p.scheduled[g.xid('a')]!.title, startsWith('de:'));
      expect(g.p.scheduleCalls, 2);
    });

    test('ayarlardan kapatınca tümü iptal; açınca yeniden zamanlanır', () async {
      final g = Rig();
      await g.start();
      g.invs.add(g.freeLive('a', g.nowMs + 24 * hour));
      g.invs.add(g.draft('d', n1: 'Ali'));
      await g.sync();
      g.invs.last.n1 = 'Ali B';
      await g.sync();
      expect(g.p.scheduled.length, 2);
      await g.r.setEnabled(false);
      await g.r.settled();
      expect(g.p.scheduled, isEmpty);
      await g.r.setEnabled(true);
      await g.r.settled();
      expect(g.p.scheduled.length, 2);
    });

    test('zamanlama hatası kaydı bozmaz: sonraki eşitlemede yeniden denenir', () async {
      final g = Rig();
      await g.start();
      g.p.failSchedule = true;
      g.invs.add(g.freeLive('a', g.nowMs + 24 * hour));
      await g.sync();
      expect(g.p.scheduled, isEmpty);
      g.p.failSchedule = false;
      await g.sync();
      expect(g.p.scheduled, hasLength(1));
    });
  });

  group('taslak hatırlatması', () {
    test('açılıştaki mevcut taslak (düzenlenmemiş) için zamanlanmaz', () async {
      final g = Rig();
      g.invs.add(g.draft('d', n1: 'Ali'));
      await g.start();
      await g.sync();
      expect(g.p.scheduled, isEmpty);
    });

    test('düzenleme +24 saat sonrasına zamanlar; boş taslağa hiç', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d');
      g.invs.add(d);
      await g.sync();
      expect(g.p.scheduled, isEmpty); // içerik yok
      d.n1 = 'Ali';
      await g.sync();
      final s = g.p.scheduled[g.did('d')]!;
      expect(s.atMs, g.nowMs + 24 * hour);
      expect(s.title, 'tr:notifDraftTitle');
      expect(s.body, 'tr:notifDraftBodyStart{n: 0}'); // zorunlu bilgilerden hiçbiri tamam değil (düğünde iki isim gerekir)
      expect(ReminderPayload.parse(s.payload)!.kind, ReminderKind.draft);
    });

    test('sık düzenlemede (1 saatten az kayma) yeniden zamanlanmaz; sonra kayar', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d');
      g.invs.add(d);
      await g.sync();
      d.n1 = 'A';
      await g.sync();
      final calls = g.p.scheduleCalls;
      final first = g.p.scheduled[g.did('d')]!.atMs;
      g.nowMs += 10 * 60 * 1000;
      d.n1 = 'Al';
      await g.sync();
      expect(g.p.scheduled[g.did('d')]!.atMs, first);
      expect(g.p.scheduleCalls, calls); // yüzde de aynı → hiç çağrı yok
      g.nowMs += 3 * hour;
      d.n1 = 'Ali';
      await g.sync();
      expect(g.p.scheduled[g.did('d')]!.atMs, g.nowMs + 24 * hour);
    });

    test('bir kez: zamanı geçtikten sonra yeniden düzenlense de bir daha zamanlanmaz', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d');
      g.invs.add(d);
      await g.sync();
      d.n1 = 'Ali';
      await g.sync();
      expect(g.p.scheduled, hasLength(1));
      g.nowMs += 25 * hour; // bildirim gösterildi (cihaz tarafında)
      await g.sync();
      d.n1 = 'Ali Veli';
      await g.sync();
      d.venue = 'Salon';
      await g.sync();
      expect(g.p.scheduleCalls, 1);
      expect(g.p.cancelled, isEmpty); // gösterilmiş olabilir: iptal edilmez
    });

    test('bir kez: uygulama yeniden başlayınca da (kalıcı durum)', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d');
      g.invs.add(d);
      await g.sync();
      d.n1 = 'Ali';
      await g.sync();
      g.nowMs += 25 * hour;
      await g.sync(); // done işaretlendi, kaydedildi
      final saved = await g.store.load();
      final g2 = Rig(initial: saved, start: g.nowMs);
      g2.invs.add(d);
      await g2.start();
      d.n1 = 'Ali Veli';
      await g2.sync();
      expect(g2.p.scheduled, isEmpty);
    });

    test('yayınlayınca iptal; silince iptal', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d');
      g.invs.add(d);
      await g.sync();
      d.n1 = 'Ali';
      await g.sync();
      d
        ..status = 'live'
        ..plan = 'premium'
        ..cloudId = 'C'
        ..expiresAt = g.nowMs + 365 * 24 * hour;
      await g.sync();
      expect(g.p.scheduled, isEmpty);

      final g2 = Rig();
      await g2.start();
      final d2 = g2.draft('e');
      g2.invs.add(d2);
      await g2.sync();
      d2.n1 = 'Ali';
      await g2.sync();
      g2.invs.clear();
      await g2.sync();
      expect(g2.p.scheduled, isEmpty);
    });

    test('kısmen hazır taslakta yüzde metni (%75)', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d');
      g.invs.add(d);
      await g.sync();
      d
        ..n1 = 'Ali'
        ..n2 = 'Veli'
        ..date = '2030-01-01'
        ..venue = 'Salon';
      await g.sync();
      expect(g.p.scheduled[g.did('d')]!.body, 'tr:notifDraftBody{n: 75}');
    });

    test('hazır taslakta (%100) "hazır" metni', () async {
      final g = Rig();
      await g.start();
      final d = g.draft('d')
        ..n1 = 'Ali'
        ..n2 = 'Veli'
        ..date = '2030-01-01'
        ..venue = 'Salon'
        ..wa = '905321234567';
      g.invs.add(d);
      await g.sync();
      d.msg = 'x'; // düzenleme
      await g.sync();
      expect(g.p.scheduled[g.did('d')]!.body, 'tr:notifDraftBodyReady{n: 100}');
    });
  });

  group('izin, ayar, dokunma', () {
    test('izin açıklaması yalnız bildirimler kapalı ve daha önce sorulmamışsa; bir kez', () async {
      final g = Rig();
      await g.start();
      g.p.enabled = true; // Android 12 ve öncesi ya da zaten verilmiş
      expect(await g.r.shouldAskPermission(), isFalse);
      g.p.enabled = false;
      expect(await g.r.shouldAskPermission(), isTrue);
      await g.r.markAsked();
      expect(await g.r.shouldAskPermission(), isFalse);
      expect((await g.store.load()).asked, isTrue);
    });

    test('hatırlatmalar kapalıyken izin istenmez', () async {
      final g = Rig(initial: ReminderState(enabled: false));
      await g.start();
      g.p.enabled = false;
      expect(await g.r.shouldAskPermission(), isFalse);
    });

    test('başlatılmadan hiçbir şey yapmaz, istisna fırlatmaz', () async {
      final r = Reminders(now: () => 0);
      r.sync();
      await r.settled();
      expect(await r.shouldAskPermission(), isFalse);
      expect(await r.setEnabled(true), isFalse);
    });

    test('ayarı açarken izin yoksa sistem izni istenir; reddedilirse false döner ama ayar açık kalır', () async {
      final g = Rig(initial: ReminderState(enabled: false));
      await g.start();
      g.p.enabled = false;
      g.p.grant = false;
      expect(await g.r.setEnabled(true), isFalse);
      expect(g.p.permissionRequests, 1);
      expect(g.r.enabled, isTrue);
      expect((await g.store.load()).enabled, isTrue);
    });

    test('bildirime dokunma ve bildirimle soğuk açılış hedefi iletir', () async {
      final g = Rig();
      g.p.launchPayload = 'x:abc';
      await g.start();
      expect(g.opened.single.invId, 'abc');
      g.p.tap!('d:zzz');
      g.p.tap!('bozuk');
      expect(g.opened.map((e) => e.invId), ['abc', 'zzz']);
    });
  });

  test('ReminderState: bozuk kayıtlar varsayılana düşer', () {
    final s = ReminderState.fromJson({'enabled': 'x', 'sched': {'x:a': 5, 'd:b': {'at': 1, 'sig': 's'}}, 'edit': {'a': 'z'}, 'done': [1, 'k']});
    expect(s.enabled, isTrue);
    expect(s.scheduled.keys, ['d:b']);
    expect(s.draftEdit, isEmpty);
    expect(s.draftDone, {'k'});
    expect(ReminderState.fromJson(null).asked, isFalse);
    expect(ReminderState.fromJson('çöp').enabled, isTrue);
  });
}
