import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../billing/billing_logic.dart';
import '../firebase_options.dart';
import '../logic/lock_rules.dart';
import '../models/invitation.dart';
import '../storage/photo_store.dart';
import 'invite_contract.dart';

/// Kullanıcıya gösterilecek hata: [key] bir ARB metin anahtarıdır.
class CloudError implements Exception {
  const CloudError(this.key, [this.detail]);

  final String key;
  final Object? detail;

  @override
  String toString() => 'CloudError($key, $detail)';
}

const Duration _opTimeout = Duration(seconds: 25);

/// Firebase katmanı: anonim giriş, Firestore belgesi, Storage fotoğrafları.
///
/// Çevrimdışı davranış: Firestore yazmaları TRANSACTION ile yapılır. Transaction'lar çevrimdışıyken
/// kuyruğa alınmaz, hata verir — böylece "uygulama yayınlanmadı sanıyor ama sonradan belge oluştu"
/// gibi hayalet yazmalar olmaz. Kalıcı önbellek kapalıdır (davetiye verisi cihazda ayrıca tutulur).
class CloudService {
  CloudService(this._photos);

  final PhotoStore _photos;
  bool _ready = false;
  Object? _initError;

  bool get ready => _ready;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _st => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _db.settings = const Settings(persistenceEnabled: false);
      _st.setMaxUploadRetryTime(const Duration(seconds: 40));
      _st.setMaxOperationRetryTime(const Duration(seconds: 20));
      _st.setMaxDownloadRetryTime(const Duration(seconds: 20));
      _ready = true;
    } catch (e) {
      _initError = e;
      debugPrint('Firebase init failed: $e');
    }
  }

  Future<String>? _signingIn;

  /// Anonim oturum (yoksa açar). Dönen değer: uid.
  /// Aynı anda gelen çağrılar (açılışta bulut + faturalandırma) tek oturum açmayı paylaşır; aksi halde
  /// iki ayrı anonim kullanıcı oluşabilirdi.
  Future<String> ensureUser() async {
    if (!_ready) throw CloudError('cloudSetup', _initError);
    final u = _auth.currentUser;
    if (u != null) return u.uid;
    return _signingIn ??= _signIn().whenComplete(() => _signingIn = null);
  }

  Future<String> _signIn() async {
    try {
      final cred = await _auth.signInAnonymously().timeout(_opTimeout);
      final uid = cred.user?.uid;
      if (uid == null) throw const CloudError('cloudErr');
      return uid;
    } catch (e) {
      throw mapError(e);
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String id) => _db.collection(kInvitesCollection).doc(id);

  // ---------------------------------------------------------------------------
  // Yayınla (ücretsiz)
  // ---------------------------------------------------------------------------

  /// Sıra: belge oluştur → fotoğrafları yükle (Storage kuralı belge sahibini okur) → data'yı URL'lerle güncelle.
  /// Başarıda [inv] alanlarını (cloudId, expiresAt, status, plan, originalDate, cloudFiles) doldurur.
  Future<void> publishFree(Invitation inv) async {
    final uid = await ensureUser();
    final origDate = inv.date;
    String? createdId;
    var files = <String, CloudFile>{};
    try {
      final now = DateTime.now().toUtc();
      final expiresAt = expiresAtFor('free', now);
      // 1) Belge (fotoğrafsız data ile)
      for (var attempt = 0; attempt < 3 && createdId == null; attempt++) {
        final candidate = generateInviteId();
        final fields = newInviteFields(
          ownerUid: uid,
          plan: 'free',
          dataJson: inviteDataJson(inv, publicId: candidate, localPlan: 'free', coverUrl: '', photoUrls: const []),
          expiresAt: expiresAt,
          lock: lockFields(inv, origDate: origDate),
        );
        final ok = await _db.runTransaction<bool>((tx) async {
          final snap = await tx.get(_doc(candidate));
          if (snap.exists) return false; // çok düşük olasılık: kimlik çakışması → yeni kimlik
          tx.set(_doc(candidate), {..._toFirestore(fields), 'createdAt': FieldValue.serverTimestamp()});
          return true;
        }, timeout: _opTimeout).timeout(_opTimeout + const Duration(seconds: 5));
        if (ok) createdId = candidate;
      }
      final id = createdId;
      if (id == null) throw const CloudError('cloudErr');

      // 2) Fotoğraflar
      files = await _syncFiles(id, inv, <String, CloudFile>{});

      // 3) data'yı URL'lerle güncelle
      if (files.isNotEmpty) {
        final data = _dataFor(inv, id, 'free', files);
        await _db.runTransaction<void>((tx) async {
          tx.update(_doc(id), {'data': data});
        }, timeout: _opTimeout).timeout(_opTimeout + const Duration(seconds: 5));
      }

      inv
        ..cloudId = id
        ..expiresAt = expiresAt.millisecondsSinceEpoch
        ..status = 'live'
        ..plan = 'free'
        ..originalDate = origDate
        ..cloudFiles = files;
    } catch (e) {
      // Yarım kalan yayını geri al (en iyi çaba)
      final id = createdId;
      if (id != null) {
        for (final f in files.values) {
          await _deleteObject(f.path, ignoreErrors: true);
        }
        try {
          await _doc(id).delete().timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      throw mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Yayınla (ücretli — Aşama 3)
  // ---------------------------------------------------------------------------

  /// Ücretli yayın. Sıra: redeemPurchase (sunucu Google Play jetonunu doğrular, belgeyi fotoğrafsız ve
  /// "paid" olarak yazar; istemci "paid" yazamaz) → fotoğrafları yükle → data'yı URL'lerle güncelle.
  /// Hak verilmezse [RedeemFailure] fırlatır. Hak verildiyse [inv] yayında işaretlenir; dönen değer null ya da
  /// fotoğraflar yüklenemediyse 'paidPhotoErr' (davetiye yine yayındadır, "Güncelle" ile tekrar denenir).
  /// [inviteId] satın almadan önce seçilir ve saklanır: yeniden denemede aynı kimlik → sunucu idempotent.
  Future<String?> publishPaid(Invitation inv, {required String purchaseToken, required String inviteId}) async {
    final origDate = inv.date;
    final data = inviteDataJson(inv, publicId: inviteId, localPlan: 'premium', coverUrl: '', photoUrls: const []);
    final res = await _redeem({
      'inviteId': inviteId,
      'purchaseToken': purchaseToken,
      'productId': kInviteProductId,
      'data': data,
    });
    final exp = res['expiresAt'];
    final sameDoc = inv.cloudId == inviteId;
    inv
      ..cloudId = inviteId
      ..expiresAt = exp is num ? exp.toInt() : expiresAtFor('paid', DateTime.now()).millisecondsSinceEpoch
      ..status = 'live'
      ..plan = 'premium'
      ..originalDate = origDate
      ..nameEditsLeft = kNameEdits
      ..dateEditsLeft = kDateEdits
      ..cloudFiles = sameDoc ? inv.cloudFiles : <String, CloudFile>{};
    try {
      final files = await _syncFiles(inviteId, inv, Map.of(inv.cloudFiles), onChange: (m) => inv.cloudFiles = Map.of(m));
      inv.cloudFiles = files;
      if (files.isNotEmpty) {
        final d = _dataFor(inv, inviteId, 'premium', files);
        await _db.runTransaction<void>((tx) async {
          tx.update(_doc(inviteId), {'data': d});
        }, timeout: _opTimeout).timeout(_opTimeout + const Duration(seconds: 5));
      }
      return null;
    } catch (e) {
      debugPrint('paid publish: photos failed: $e');
      return 'paidPhotoErr';
    }
  }

  /// Davetiyesiz doğrulama (açılışta bulunan tüketilmemiş alım): sunucu bu jetonla daha önce hak verdiyse
  /// başarı döner (uygulama tüketir); vermediyse RedeemFailure('payCredit', keep) — kullanılmamış hak.
  Future<void> redeemGranted(String purchaseToken) async {
    await _redeem({'purchaseToken': purchaseToken, 'productId': kInviteProductId});
  }

  /// users/{uid}.premium (reklamsız) — yalnız sunucu yazar. Hata: false.
  Future<bool> fetchPremium() async {
    try {
      final uid = await ensureUser();
      final s = await _db.collection('users').doc(uid).get().timeout(_opTimeout);
      return s.data()?['premium'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _redeem(Map<String, Object> payload) async {
    if (!_ready) throw const RedeemFailure('cloudSetup', RedeemAction.keep);
    try {
      await ensureUser();
    } on CloudError catch (e) {
      throw RedeemFailure(e.key, RedeemAction.keep);
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: kFunctionsRegion).httpsCallable(
        kRedeemFunction,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
      );
      final res = await callable.call<Object?>(payload).timeout(const Duration(seconds: 80));
      final d = res.data;
      if (d is! Map || d['ok'] != true) throw const RedeemFailure('payVerifyErr', RedeemAction.keep);
      return d.map((k, v) => MapEntry('$k', v));
    } on FirebaseFunctionsException catch (e) {
      debugPrint('redeemPurchase: ${e.code} ${e.message}');
      throw redeemFailureFor(e.code, e.message);
    } on RedeemFailure {
      rethrow;
    } catch (e) {
      debugPrint('redeemPurchase failed: $e');
      throw const RedeemFailure('payVerifyErr', RedeemAction.keep);
    }
  }

  // ---------------------------------------------------------------------------
  // Güncelle
  // ---------------------------------------------------------------------------

  /// Yayındaki davetiyeyi buluta yazar (değişen fotoğraflar yüklenir, kaldırılanlar silinir).
  Future<void> update(Invitation inv) async {
    final id = inv.cloudId;
    if (id == null) throw const CloudError('cloudGone');
    await ensureUser();
    final localPlan = inv.plan ?? 'free';
    try {
      final files = await _syncFiles(id, inv, Map.of(inv.cloudFiles), onChange: (m) => inv.cloudFiles = Map.of(m));
      inv.cloudFiles = files;
      final data = _dataFor(inv, id, localPlan, files);
      final lock = lockFields(inv, origDate: inv.originalDate ?? inv.date)..remove('origDate');
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(_doc(id));
        if (!snap.exists) throw const CloudError('cloudGone');
        tx.update(_doc(id), {'data': data, ...lock});
      }, timeout: _opTimeout).timeout(_opTimeout + const Duration(seconds: 5));
    } catch (e) {
      throw mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Sil
  // ---------------------------------------------------------------------------

  /// Önce Storage dosyaları (kural belgenin sahibini okur), sonra belge.
  Future<void> delete(Invitation inv) async {
    final id = inv.cloudId;
    if (id == null) return;
    await ensureUser();
    try {
      for (final f in inv.cloudFiles.values.toList()) {
        await _deleteObject(f.path);
      }
      // İzlenmeyen eski dosyalar kalmasın (ör. yarım kalmış yükleme): klasörü listele ve sil.
      try {
        final list = await _st.ref('$kInvitesCollection/$id').listAll().timeout(_opTimeout);
        for (final r in list.items) {
          await _deleteObject(r.fullPath);
        }
      } on FirebaseException catch (_) {
        // Listeleme yetkisi yoksa (kural: list kapalı olabilir) geç.
      }
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(_doc(id));
        if (snap.exists) tx.delete(_doc(id));
      }, timeout: _opTimeout).timeout(_opTimeout + const Duration(seconds: 5));
    } catch (e) {
      throw mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------------

  String _dataFor(Invitation inv, String id, String localPlan, Map<String, CloudFile> files) {
    final cover = inv.cover.isEmpty ? '' : (files[inv.cover]?.url ?? '');
    final photos = [
      for (final p in inv.photos)
        if (files[p] != null) files[p]!.url,
    ];
    final json = inviteDataJson(inv, publicId: id, localPlan: localPlan, coverUrl: cover, photoUrls: photos);
    if (json.length >= kMaxDataBytes) throw const CloudError('cloudErr', 'data too large');
    return json;
  }

  /// Yerel fotoğrafları buluttakilerle eşitler. Dönen değer: yeni eşleme (yerel ad → bulut dosyası).
  Future<Map<String, CloudFile>> _syncFiles(
    String id,
    Invitation inv,
    Map<String, CloudFile> current, {
    void Function(Map<String, CloudFile>)? onChange,
  }) async {
    final wanted = <String>{if (inv.cover.isNotEmpty) inv.cover, ...inv.photos};
    // 1) Artık kullanılmayanları sil (kapak ↔ galeri rol değişimi de dahil)
    for (final e in current.entries.toList()) {
      final isCoverPath = e.value.path.startsWith(storagePath(id, 'cover.'));
      final roleOk = isCoverPath ? e.key == inv.cover : inv.photos.contains(e.key);
      if (!wanted.contains(e.key) || !roleOk) {
        await _deleteObject(e.value.path);
        current.remove(e.key);
        onChange?.call(current);
      }
    }
    // 2) Kapak
    if (inv.cover.isNotEmpty && !current.containsKey(inv.cover)) {
      final f = await _upload(id, 'cover', inv.cover);
      if (f != null) {
        current[inv.cover] = f;
        onChange?.call(current);
      }
    }
    // 3) Galeri (sıra data.photos'ta tutulur; yuva adları kalıcıdır, yeniden sıralamada yükleme yok)
    for (final p in inv.photos) {
      if (current.containsKey(p)) continue;
      final slot = freeGallerySlot(id, current.values.map((f) => f.path));
      if (slot == null) break;
      final f = await _upload(id, slot, p);
      if (f != null) {
        current[p] = f;
        onChange?.call(current);
      }
    }
    return current;
  }

  Future<CloudFile?> _upload(String id, String slot, String localName) async {
    Uint8List bytes;
    try {
      bytes = await _photos.fileFor(localName).readAsBytes();
    } on FileSystemException {
      return null; // yerel dosya yok → atla
    }
    final mime = PhotoStore.sniffMime(bytes);
    if (mime == null) return null;
    if (bytes.length >= kMaxUploadBytes) throw const CloudError('photoTooBig');
    final path = storagePath(id, storageFileName(slot, mime));
    final ref = _st.ref(path);
    await ref
        .putData(bytes, SettableMetadata(contentType: mime, cacheControl: 'public, max-age=86400'))
        .timeout(const Duration(seconds: 90));
    final url = await ref.getDownloadURL().timeout(_opTimeout);
    return CloudFile(path: path, url: url);
  }

  Future<void> _deleteObject(String path, {bool ignoreErrors = false}) async {
    try {
      await _st.ref(path).delete().timeout(_opTimeout);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      // Belge silinmişse (TTL) kural sahibi doğrulayamaz → dosya zaten sahipsiz; geç.
      if (e.code == 'unauthorized') return;
      if (!ignoreErrors) rethrow;
    } catch (_) {
      if (!ignoreErrors) rethrow;
    }
  }

  static Map<String, Object> _toFirestore(Map<String, Object> m) =>
      m.map((k, v) => MapEntry(k, v is DateTime ? Timestamp.fromDate(v) : v));

  /// Firebase/ağ hatalarını kullanıcı metin anahtarına çevirir.
  static CloudError mapError(Object e) {
    if (e is CloudError) return e;
    if (e is TimeoutException || e is SocketException) return CloudError('netErr', e);
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unavailable':
        case 'network-request-failed':
        case 'deadline-exceeded':
        case 'retry-limit-exceeded':
        case 'too-many-requests':
          return CloudError('netErr', e);
        case 'permission-denied':
        case 'unauthorized':
        case 'unauthenticated':
          return CloudError('cloudDenied', e);
        case 'operation-not-allowed':
        case 'admin-restricted-operation':
        case 'configuration-not-found':
        case 'bucket-not-found':
        case 'project-not-found':
        case 'not-found':
        case 'failed-precondition':
          return CloudError('cloudSetup', e);
        case 'quota-exceeded':
        case 'resource-exhausted':
          return CloudError('cloudErr', e);
      }
    }
    return CloudError('cloudErr', e);
  }
}
