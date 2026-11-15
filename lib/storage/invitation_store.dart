import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../billing/billing_logic.dart';
import '../models/invitation.dart';

/// Taslaklar ve ayarlar: shared_preferences (Aşama 2'de Firestore ile eşitlenecek).
class InvitationStore {
  static const _kInvs = 'zarfla_invs_v1';
  static const _kLang = 'zarfla_lang';
  static const _kPrem = 'zarfla_premium_user';
  static const _kPendingPaid = 'zarfla_pending_paid_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();

  /// Okunamayan (bozuk) kayıtların ham kopyası: bir sonraki kaydetmede kaybolmasın diye ayrı anahtarda saklanır.
  static const _kInvsBad = 'zarfla_invs_unreadable_v1';

  /// Tüm davetiyeler. ASLA istisna fırlatmaz: bozuk tek kayıt atlanır (ham hali [_kInvsBad]'a yedeklenir),
  /// diğerleri yüklenir. Tümü okunamazsa boş liste döner ve ham metin yedeklenir.
  Future<List<Invitation>> loadAll() async {
    try {
      final p = await _p();
      Object? raw;
      try {
        raw = p.get(_kInvs);
      } catch (e) {
        debugPrint('zarfla: invitations key unreadable: $e');
        return <Invitation>[];
      }
      final r = decodeInvitations(raw);
      if (r.unreadable.isNotEmpty) {
        debugPrint('zarfla: ${r.unreadable.length} unreadable invitation record(s) backed up');
        try {
          final prev = p.getString(_kInvsBad);
          final all = <Object?>[];
          if (prev != null && prev.isNotEmpty) {
            try {
              final d = jsonDecode(prev);
              if (d is List) all.addAll(d);
            } catch (_) {}
          }
          final known = {for (final x in all) jsonEncode(x)};
          for (final x in r.unreadable) {
            if (known.add(jsonEncode(x))) all.add(x);
          }
          await p.setString(_kInvsBad, jsonEncode(all.length > 50 ? all.sublist(all.length - 50) : all));
        } catch (_) {}
      }
      return r.invitations;
    } catch (e) {
      debugPrint('zarfla: loadAll failed: $e');
      return <Invitation>[];
    }
  }

  Future<bool> saveAll(List<Invitation> invs) async {
    try {
      final p = await _p();
      return await p.setString(_kInvs, jsonEncode(invs.map((e) => e.toJson()).toList()));
    } catch (_) {
      return false;
    }
  }

  Future<String?> loadLang() async {
    try {
      final v = (await _p()).get(_kLang);
      return v is String ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLang(String lang) async {
    try {
      await (await _p()).setString(_kLang, lang);
    } catch (e) {
      debugPrint('zarfla: saveLang failed: $e');
    }
  }

  Future<bool> loadFlag(String key) async => _bool(key);

  /// Tür uyuşmazlığına dayanıklı bool okuma (eski sürüm farklı türde yazmış olabilir).
  Future<bool> _bool(String key) async {
    try {
      final v = (await _p()).get(key);
      if (v is bool) return v;
      if (v is String) return v == 'true' || v == '1';
      if (v is int) return v != 0;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveFlag(String key, bool v) async {
    try {
      await (await _p()).setBool(key, v);
    } catch (e) {
      debugPrint('zarfla: saveFlag failed: $e');
    }
  }

  Future<bool> loadPremiumUser() async => _bool(_kPrem);

  Future<void> savePremiumUser(bool v) async {
    try {
      await (await _p()).setBool(_kPrem, v);
    } catch (e) {
      debugPrint('zarfla: savePremiumUser failed: $e');
    }
  }

  /// Satın alma bağlamı (ücretli yayın sürerken; bkz. PendingPaid). null = temizle.
  Future<PendingPaid?> loadPendingPaid() async {
    try {
      final raw = (await _p()).get(_kPendingPaid);
      if (raw is! String || raw.isEmpty) return null;
      return PendingPaid.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> savePendingPaid(PendingPaid? v) async {
    try {
      final p = await _p();
      if (v == null) {
        await p.remove(_kPendingPaid);
      } else {
        await p.setString(_kPendingPaid, jsonEncode(v.toJson()));
      }
    } catch (e) {
      debugPrint('zarfla: savePendingPaid failed: $e');
    }
  }
}

/// Kayıtlı davetiye listesinin çözümlenmesi (saf işlev; test edilebilir).
/// [raw]: SharedPreferences'taki değer (normalde JSON metni). Her kayıt ayrı ayrı çözülür:
/// bozuk olanlar [unreadable]'a ham haliyle konur, kimliği boş/yinelenen kayıtlara benzersiz kimlik verilir.
({List<Invitation> invitations, List<Object?> unreadable}) decodeInvitations(Object? raw) {
  final out = <Invitation>[];
  final bad = <Object?>[];
  if (raw == null) return (invitations: out, unreadable: bad);
  Object? list;
  if (raw is String) {
    if (raw.trim().isEmpty) return (invitations: out, unreadable: bad);
    try {
      list = jsonDecode(raw);
    } catch (_) {
      return (invitations: out, unreadable: [raw]);
    }
  } else {
    list = raw;
  }
  if (list is Map) list = [list]; // çok eski/elle bozulmuş tek kayıt
  if (list is! List) return (invitations: out, unreadable: [raw is String ? raw : '$raw']);
  final seen = <String>{};
  var i = 0;
  for (final e in list) {
    i++;
    if (e is! Map) {
      if (e != null) bad.add(e);
      continue;
    }
    try {
      final m = <String, dynamic>{};
      e.forEach((k, v) => m['$k'] = v);
      final inv = Invitation.fromJson(m);
      if (inv.id.trim().isEmpty || seen.contains(inv.id)) {
        var n = 1;
        final base = inv.id.trim().isEmpty ? 'r${inv.created.abs().toRadixString(36)}$i' : inv.id;
        var id = inv.id.trim().isEmpty ? base : '${base}_$n';
        while (seen.contains(id)) {
          n++;
          id = '${base}_$n';
        }
        inv.id = id;
      }
      seen.add(inv.id);
      out.add(inv);
    } catch (err) {
      debugPrint('zarfla: invitation record $i unreadable: $err');
      try {
        bad.add(jsonDecode(jsonEncode(e)));
      } catch (_) {
        bad.add('$e');
      }
    }
  }
  return (invitations: out, unreadable: bad);
}
