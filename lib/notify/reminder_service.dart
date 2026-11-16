import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/progress.dart';
import '../models/invitation.dart';
import 'reminder_logic.dart';
import 'reminder_platform.dart';
import 'reminder_store.dart';

/// Orkestranın uygulamadan ihtiyaç duyduğu şeyler (AppState'e doğrudan bağımlı olmamak için işlevlerle verilir).
class ReminderHost {
  ReminderHost({required this.invitations, required this.lang, required this.text, this.onOpen});

  final List<Invitation> Function() invitations;
  final String Function() lang;

  /// [lang] dilinde ARB metni (yer tutucular {n}).
  final String Function(String lang, String key, Map<String, Object> args) text;

  /// Bildirime dokunulunca (uygulama açıkken ya da bildirimle açılırken) çağrılır.
  final void Function(ReminderPayload payload)? onOpen;
}

/// Yerel hatırlatma orkestrası. Davetiye listesinden "olması gereken" hatırlatmaları hesaplar, cihazdakiyle
/// karşılaştırıp yalnız farkı zamanlar/iptal eder. [sync] her kaydetmede çağrılır; hiçbir koşulda istisna fırlatmaz,
/// başlatılmadıysa (testler, güvenli kip, eklenti hatası) hiçbir şey yapmaz.
class Reminders {
  Reminders({int Function()? now, LocalClock? clock})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _clock = clock ?? ((ms) => DateTime.fromMillisecondsSinceEpoch(ms));

  /// Uygulama genelindeki örnek (main.dart başlatır).
  static final Reminders instance = Reminders();

  final int Function() _now;
  final LocalClock _clock;

  ReminderPlatform? _platform;
  ReminderStore? _store;
  ReminderHost? _host;
  ReminderState? _state;
  bool _ready = false;
  bool _first = true;
  Future<void> _chain = Future<void>.value();

  /// Bu oturumda gördüğümüz taslak parmak izleri (ilk eşitlemeden sonra değişiklik = düzenleme).
  final Map<String, String> _fp = {};

  bool get ready => _ready;
  bool get enabled => _state?.enabled ?? false;
  bool get asked => _state?.asked ?? false;

  /// Başlatır. İzin İSTEMEZ. Bildirimle açıldıysa o bildirimin hedefini açar.
  Future<void> start({required ReminderPlatform platform, required ReminderStore store, required ReminderHost host}) async {
    _platform = platform;
    _store = store;
    _host = host;
    _state = await store.load();
    final launch = await platform.init(_onTap);
    _ready = true;
    await _enqueue();
    final p = ReminderPayload.parse(launch);
    if (p != null) host.onOpen?.call(p);
  }

  void _onTap(String? payload) {
    final p = ReminderPayload.parse(payload);
    if (p != null) _host?.onOpen?.call(p);
  }

  /// Davetiye listesi ya da dil değişti: hatırlatmaları yeniden hesapla (arka planda, sıralı).
  void sync() {
    if (!_ready) return;
    unawaited(_enqueue());
  }

  Future<void> _enqueue() {
    final next = _chain.then((_) => _syncNow()).catchError((Object e, StackTrace st) {
      debugPrint('zarfla: reminder sync failed: $e');
    });
    _chain = next;
    return next;
  }

  /// Sıradaki eşitlemenin bittiği an (testler için).
  Future<void> settled() => _chain;

  Future<void> _syncNow() async {
    final p = _platform, st = _state, host = _host, store = _store;
    if (!_ready || p == null || st == null || host == null || store == null) return;
    final now = _now();
    final lang = host.lang();
    final invs = host.invitations();
    var dirty = false;
    final baseline = _first;
    _first = false;

    // 1) Zamanı geçmiş kayıtlar: bildirim gösterilmiş sayılır (iptal EDİLMEZ: Doze'da gecikmiş olabilir).
    for (final k in st.scheduled.keys.toList()) {
      if (st.scheduled[k]!.atMs <= now) {
        st.scheduled.remove(k);
        if (k.startsWith('d:')) st.draftDone.add(k.substring(2));
        dirty = true;
      }
    }

    // 2) Olması gerekenler.
    final desired = <String, ReminderSpec>{};
    for (final inv in invs) {
      if (inv.isLive) {
        final exp = inv.expiresAt;
        if (inv.plan == 'free' && inv.cloudId != null && exp != null) {
          final plan = planExpiryReminder(exp, now, clock: _clock);
          if (plan != null) {
            final s = ReminderSpec(kind: ReminderKind.expiry, invId: inv.id, atMs: plan.atMs, extra: plan.hoursLeft);
            desired[s.key] = s;
          }
        }
        continue;
      }
      if (st.draftDone.contains(inv.id) || !draftHasUserContent(inv)) continue;
      final fp = draftFingerprint(inv);
      final known = _fp[inv.id];
      _fp[inv.id] = fp;
      if (known != fp && !(baseline && known == null)) {
        st.draftEdit[inv.id] = now;
        dirty = true;
      }
      final last = st.draftEdit[inv.id];
      if (last == null) continue;
      final key = reminderKey(ReminderKind.draft, inv.id);
      final at = stableDraftAt(currentAtMs: st.scheduled[key]?.atMs, plannedAtMs: planDraftReminder(last, clock: _clock));
      if (at <= now) {
        st.draftDone.add(inv.id);
        dirty = true;
        continue;
      }
      final s = ReminderSpec(kind: ReminderKind.draft, invId: inv.id, atMs: at, extra: readyPercent(inv));
      desired[s.key] = s;
    }
    if (!st.enabled) desired.clear();

    // 3) Fark → platform.
    final diff = diffReminders(scheduled: st.scheduled, desired: desired, lang: lang);
    for (final k in diff.cancel) {
      try {
        await p.cancel(_idOfKey(k));
        st.scheduled.remove(k);
        dirty = true;
      } catch (e) {
        debugPrint('zarfla: reminder cancel failed: $e');
      }
    }
    for (final s in diff.schedule) {
      try {
        final isExpiry = s.kind == ReminderKind.expiry;
        String tx(String key, [Map<String, Object> a = const {}]) => host.text(lang, key, a);
        await p.schedule(
          id: reminderNotificationId(s.kind, s.invId),
          title: isExpiry ? tx('notifExpiryTitle', {'n': s.extra}) : tx('notifDraftTitle'),
          body: isExpiry ? tx('notifExpiryBody') : tx(draftBodyKey(s.extra), {'n': s.extra}),
          atMs: s.atMs,
          payload: ReminderPayload(s.kind, s.invId).encode(),
          channelName: tx('notifChannelName'),
          channelDesc: tx('notifChannelDesc'),
        );
        st.scheduled[s.key] = ScheduledReminder(atMs: s.atMs, sig: reminderSig(s, lang));
        dirty = true;
      } catch (e) {
        debugPrint('zarfla: reminder schedule failed: $e');
      }
    }

    // 4) Silinmiş davetiyelerin kalıntılarını temizle.
    final ids = {for (final i in invs) i.id};
    for (final k in st.draftEdit.keys.where((k) => !ids.contains(k)).toList()) {
      st.draftEdit.remove(k);
      dirty = true;
    }
    for (final k in st.draftDone.where((k) => !ids.contains(k)).toList()) {
      st.draftDone.remove(k);
      dirty = true;
    }
    _fp.removeWhere((k, _) => !ids.contains(k));
    if (dirty) await store.save(st);
  }

  static int _idOfKey(String key) {
    final kind = key.startsWith('x:') ? ReminderKind.expiry : ReminderKind.draft;
    return reminderNotificationId(kind, key.substring(2));
  }

  // ---- İzin ve ayar ----

  /// Açıklama + izin penceresi gösterilmeli mi? (Açık, daha önce sorulmamış ve bildirimler kapalıysa.)
  Future<bool> shouldAskPermission() async {
    final st = _state, p = _platform;
    if (!_ready || st == null || p == null || !st.enabled || st.asked) return false;
    return !await p.notificationsEnabled();
  }

  Future<void> markAsked() async {
    final st = _state;
    if (st == null || st.asked) return;
    st.asked = true;
    await _store?.save(st);
  }

  Future<bool> requestPermission() async => await _platform?.requestPermission() ?? false;

  Future<bool> notificationsEnabled() async => await _platform?.notificationsEnabled() ?? false;

  /// Ayarlar anahtarı. Açılırken izin yoksa sistem izin penceresi istenir; sonuç (izin var mı) döner.
  /// Anahtar izin olmasa da açık kalır (izin sonradan sistem ayarlarından verilebilir).
  Future<bool> setEnabled(bool on) async {
    final st = _state;
    if (st == null) return false;
    st.enabled = on;
    await _store?.save(st);
    var granted = true;
    if (on) {
      granted = await notificationsEnabled();
      if (!granted) {
        st.asked = true;
        granted = await requestPermission();
        await _store?.save(st);
      }
    }
    await _enqueue();
    return granted;
  }
}
