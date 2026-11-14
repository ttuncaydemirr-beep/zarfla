import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/invitation.dart';

/// Taslaklar ve ayarlar: shared_preferences (Aşama 2'de Firestore ile eşitlenecek).
class InvitationStore {
  static const _kInvs = 'zarfla_invs_v1';
  static const _kLang = 'zarfla_lang';
  static const _kPrem = 'zarfla_premium_user';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();

  Future<List<Invitation>> loadAll() async {
    final p = await _p();
    final raw = p.getString(_kInvs);
    if (raw == null || raw.isEmpty) return <Invitation>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <Invitation>[];
      return [
        for (final e in list)
          if (e is Map) Invitation.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
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

  Future<String?> loadLang() async => (await _p()).getString(_kLang);

  Future<void> saveLang(String lang) async {
    await (await _p()).setString(_kLang, lang);
  }

  Future<bool> loadPremiumUser() async => (await _p()).getBool(_kPrem) ?? false;

  Future<void> savePremiumUser(bool v) async {
    await (await _p()).setBool(_kPrem, v);
  }
}
