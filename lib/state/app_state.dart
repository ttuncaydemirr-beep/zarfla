import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/catalog.dart';
import '../l10n/strings.dart';
import '../logic/lock_rules.dart';
import '../models/invitation.dart';
import '../storage/invitation_store.dart';
import '../storage/photo_store.dart';

/// Uygulama durumu: tek ChangeNotifier + provider.
/// Neden provider: tek ekranlı akış ve az sayıda paylaşılan durum için en sade,
/// en yaygın ve kod üretimi gerektirmeyen seçenek (riverpod'a gerek yok).
class AppState extends ChangeNotifier {
  AppState({required this.strings, required InvitationStore store, required PhotoStore photos})
      : _store = store,
        _photos = photos;

  final AppStrings strings;
  final InvitationStore _store;
  final PhotoStore _photos;

  String lang = 'tr';
  bool premiumUser = false;
  final List<Invitation> invitations = [];

  /// Son kaydetme başarısız olduysa true (cihazda yer yok).
  bool lastSaveFailed = false;

  Future<void> init() async {
    await _photos.init();
    final l = await _store.loadLang();
    if (l != null && kLangs.contains(l)) lang = l;
    premiumUser = await _store.loadPremiumUser();
    invitations
      ..clear()
      ..addAll(await _store.loadAll());
  }

  String t(String key, [Map<String, Object> args = const {}]) => strings.get(lang, key, args);

  Future<void> setLang(String l) async {
    if (!kLangs.contains(l)) return;
    lang = l;
    notifyListeners();
    await _store.saveLang(l);
  }

  Invitation? byId(String id) {
    for (final i in invitations) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<Invitation> get sorted => invitations.toList()..sort((a, b) => b.created.compareTo(a.created));

  static final _rnd = Random();
  String newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(6, (_) => chars[_rnd.nextInt(chars.length)]).join();
    return r + DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(4);
  }

  Invitation createDraft(String type) =>
      Invitation.create(id: newId(), type: type, lang: lang, now: DateTime.now().millisecondsSinceEpoch);

  Future<bool> add(Invitation inv) async {
    invitations.add(inv);
    return save();
  }

  /// Değişikliği kaydet ve ekranları yenile.
  Future<bool> save({bool notify = true}) async {
    if (notify) notifyListeners();
    final ok = await _store.saveAll(invitations);
    lastSaveFailed = !ok;
    return ok;
  }

  Future<void> delete(Invitation inv) async {
    invitations.removeWhere((i) => i.id == inv.id);
    await save();
    await _photos.delete(inv.cover);
    for (final p in inv.photos) {
      await _photos.delete(p);
    }
  }

  /// Yayınla (Aşama 1: ücretli satın alma SAHTE; akış test için yayınlanmış sayılır).
  Future<void> publish(Invitation inv, String plan) async {
    markPublished(inv, plan);
    if (plan == 'premium' && !premiumUser) {
      premiumUser = true;
      await _store.savePremiumUser(true);
    }
    await save();
  }

  // ---- Fotoğraflar ----
  File photoFile(String name) => _photos.fileFor(name);

  Future<String> photoDataUri(String name) => _photos.dataUri(name);

  /// Kapak ayarla. Dönen değer: null (başarılı) ya da hata metin anahtarı.
  Future<String?> setCover(Invitation inv, Uint8List bytes) async {
    String name;
    try {
      name = await _photos.saveBytes(bytes);
    } on FileSystemException {
      return 'quota';
    } catch (_) {
      return 'photoErr';
    }
    final old = inv.cover;
    inv.cover = name;
    if (!await save()) {
      inv.cover = old;
      await _photos.delete(name);
      await save();
      return 'quota';
    }
    await _photos.delete(old);
    return null;
  }

  Future<void> removeCover(Invitation inv) async {
    final old = inv.cover;
    inv.cover = '';
    await save();
    await _photos.delete(old);
  }

  /// Galeriye ekle (en çok 6). Dönen değer: null ya da uyarı metin anahtarı.
  Future<String?> addPhotos(Invitation inv, List<Uint8List> items) async {
    final room = kMaxGallery - inv.photos.length;
    if (room <= 0) return 'galFull';
    String? warn = items.length > room ? 'galFull' : null;
    for (final bytes in items.take(room)) {
      String name;
      try {
        name = await _photos.saveBytes(bytes);
      } on FileSystemException {
        return 'quota';
      } catch (_) {
        warn = 'photoErr';
        continue;
      }
      inv.photos.add(name);
      if (!await save(notify: false)) {
        inv.photos.removeLast();
        await _photos.delete(name);
        await save(notify: false);
        warn = 'quota';
        break;
      }
    }
    notifyListeners();
    return warn;
  }

  Future<void> removePhoto(Invitation inv, int i) async {
    if (i < 0 || i >= inv.photos.length) return;
    final name = inv.photos.removeAt(i);
    await save();
    await _photos.delete(name);
  }

  Future<void> movePhotoEarlier(Invitation inv, int i) async {
    if (i <= 0 || i >= inv.photos.length) return;
    final x = inv.photos[i];
    inv.photos[i] = inv.photos[i - 1];
    inv.photos[i - 1] = x;
    await save();
  }

  /// Davetli sayfasına gidecek veri (fotoğraflar data URI).
  Future<Map<String, dynamic>> inviteData(Invitation inv) async {
    final cover = await _photos.dataUri(inv.cover);
    final photos = <String>[];
    for (final p in inv.photos) {
      final d = await _photos.dataUri(p);
      if (d.isNotEmpty) photos.add(d);
    }
    return inv.toInviteData(coverSrc: cover, photoSrcs: photos);
  }
}
