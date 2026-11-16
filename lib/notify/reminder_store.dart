import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_logic.dart';

/// Hatırlatmaların kalıcı durumu (davetiye kayıtlarına DOKUNMAZ; ayrı bir SharedPreferences anahtarı).
class ReminderState {
  ReminderState({
    this.enabled = true,
    this.asked = false,
    Map<String, ScheduledReminder>? scheduled,
    Map<String, int>? draftEdit,
    Set<String>? draftDone,
  })  : scheduled = scheduled ?? {},
        draftEdit = draftEdit ?? {},
        draftDone = draftDone ?? {};

  /// Ayarlardaki anahtar: kapalıysa hiçbir hatırlatma zamanlanmaz.
  bool enabled;

  /// Bildirim izni açıklaması bir kez gösterildi mi (yeniden sorulmaz; sonradan Ayarlar'dan açılır).
  bool asked;

  /// Cihazda zamanlanmış hatırlatmalar (anahtar: "x:<id>" / "d:<id>").
  final Map<String, ScheduledReminder> scheduled;

  /// Taslağın son düzenleme anı (ms).
  final Map<String, int> draftEdit;

  /// Hatırlatması zaten gönderilmiş (ya da gönderilecek zamanı geçmiş) taslaklar: bir daha zamanlanmaz.
  final Set<String> draftDone;

  Map<String, Object?> toJson() => {
        'v': 1,
        'enabled': enabled,
        'asked': asked,
        'sched': scheduled.map((k, v) => MapEntry(k, v.toJson())),
        'edit': draftEdit,
        'done': draftDone.toList(),
      };

  /// Bozuk/eksik veriye dayanıklı: asla istisna fırlatmaz.
  factory ReminderState.fromJson(Object? j) {
    final s = ReminderState();
    if (j is! Map) return s;
    if (j['enabled'] is bool) s.enabled = j['enabled'] as bool;
    if (j['asked'] is bool) s.asked = j['asked'] as bool;
    final sched = j['sched'];
    if (sched is Map) {
      sched.forEach((k, v) {
        final r = ScheduledReminder.fromJson(v);
        if (k is String && r != null) s.scheduled[k] = r;
      });
    }
    final edit = j['edit'];
    if (edit is Map) {
      edit.forEach((k, v) {
        if (k is String && v is int) s.draftEdit[k] = v;
      });
    }
    final done = j['done'];
    if (done is List) {
      for (final e in done) {
        if (e is String) s.draftDone.add(e);
      }
    }
    return s;
  }
}

abstract class ReminderStore {
  Future<ReminderState> load();
  Future<void> save(ReminderState s);
}

class MemoryReminderStore implements ReminderStore {
  MemoryReminderStore([ReminderState? initial]) : _json = initial == null ? null : jsonEncode(initial.toJson());

  String? _json;

  @override
  Future<ReminderState> load() async => ReminderState.fromJson(_json == null ? null : jsonDecode(_json!));

  @override
  Future<void> save(ReminderState s) async => _json = jsonEncode(s.toJson());
}

class PrefsReminderStore implements ReminderStore {
  static const _key = 'zarfla_reminders_v1';

  @override
  Future<ReminderState> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.get(_key);
      if (raw is! String || raw.isEmpty) return ReminderState();
      return ReminderState.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('zarfla: reminder state unreadable: $e');
      return ReminderState();
    }
  }

  @override
  Future<void> save(ReminderState s) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(s.toJson()));
    } catch (e) {
      debugPrint('zarfla: reminder state save failed: $e');
    }
  }
}
