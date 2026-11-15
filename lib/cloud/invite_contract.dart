import 'dart:convert';
import 'dart:math';

import '../logic/lock_rules.dart';
import '../models/invitation.dart';

/// Zarfla ↔ davetli sayfası (stüdyo sitesi) VERİ SÖZLEŞMESİ — Firebase'e bağımlı değildir (test edilebilir).
///
/// Firestore: invites/{id}
///   ownerUid  string    anonim kullanıcının uid'i
///   schema    int       1
///   data      string    Invitation.toInviteData() JSON'u (fotoğraflar Storage indirme URL'leri)
///   plan      string    "free" | "paid"
///   status    string    "live"
///   createdAt timestamp serverTimestamp
///   expiresAt timestamp free: yayın + 24 saat · paid: yayın + 365 gün
///   deleteAt  timestamp expiresAt + 30 gün (Firestore TTL alanı)
///   type, theme, n1, n2, date (YYYY-MM-DD), origDate, nameEdits (int), dateEdits (int)  — kilit alanları
/// Storage: invites/{id}/cover.EXT, invites/{id}/g1.EXT … g6.EXT (< 2 MB, image/*)
/// Bağlantı: https://ttuncaydemirr-beep.github.io/davetiye/?id={id}

const int kInviteSchema = 1;
const int kInviteIdLength = 12;
const String kInviteIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const String kInvitesCollection = 'invites';

const String kInviteBaseUrl = 'https://ttuncaydemirr-beep.github.io/davetiye/';

const Duration kFreeLife = Duration(hours: 24);
const Duration kPaidLife = Duration(days: 365);
const Duration kTtlGrace = Duration(days: 30);

/// Storage'a yüklenen her dosya için üst sınır (kurallarla aynı).
const int kMaxUploadBytes = 2 * 1024 * 1024;

/// data alanı için üst sınır (kurallar: < 200 KB).
const int kMaxDataBytes = 200 * 1024;

/// Aynı anda en fazla bu kadar aktif ücretsiz davetiye (istemci denetimi).
const int kMaxActiveFree = 1;

final RegExp _idRe = RegExp(r'^[A-Za-z0-9]{12}$');

/// 12 karakter, [A-Za-z0-9], kriptografik rastgele. (62 karakter → modulo sapması yok sayılabilir değil:
/// 256 % 62 ≠ 0 olduğundan reddetme örneklemesi kullanılır.)
String generateInviteId([Random? random]) {
  final r = random ?? Random.secure();
  final b = StringBuffer();
  while (b.length < kInviteIdLength) {
    final v = r.nextInt(256);
    if (v >= 248) continue; // 248 = 62 * 4 → eşit dağılım
    b.write(kInviteIdChars[v % 62]);
  }
  return b.toString();
}

bool isValidInviteId(String s) => _idRe.hasMatch(s);

/// Davetiyenin tam bağlantısı (paylaşım metinleri dahil her yerde bu kullanılır).
String inviteUrl(String id) => '$kInviteBaseUrl?id=$id';

/// Ekranda gösterilen kısa biçim (https:// olmadan).
String inviteUrlDisplay(String id) => inviteUrl(id).replaceFirst('https://', '');

/// Yerel plan ('free' | 'premium') → bulut planı ('free' | 'paid').
String cloudPlanOf(String? localPlan) => localPlan == 'premium' ? 'paid' : 'free';

DateTime expiresAtFor(String cloudPlan, DateTime publishedAt) =>
    publishedAt.toUtc().add(cloudPlan == 'paid' ? kPaidLife : kFreeLife);

DateTime deleteAtFor(DateTime expiresAt) => expiresAt.toUtc().add(kTtlGrace);

/// Kurallar isimlerde çift tırnak, ters bölü ve kontrol karakterlerine izin vermez
/// (JSON içindeki kaçışsız değerle birebir karşılaştırma yapılabilsin diye).
final RegExp kCloudNameForbidden = RegExp(r'["\\\x00-\x1f]');

String cloudSafeName(String s) => s.replaceAll(kCloudNameForbidden, '');

/// Firestore `data` alanı: toInviteData JSON'u. id = bulut kimliği, status = live.
String inviteDataJson(
  Invitation inv, {
  required String publicId,
  required String localPlan,
  required String coverUrl,
  required List<String> photoUrls,
}) {
  final m = inv.toInviteData(coverSrc: coverUrl, photoSrcs: photoUrls, publicId: publicId, planOverride: localPlan);
  m['status'] = 'live';
  m['plan'] = localPlan; // davetli sayfası 'premium' görünce "Zarfla ile hazırlandı" yazısını gizler
  return jsonEncode(m);
}

/// Kilit alanları (kurallar bunları ve data JSON'unu birbirine bağlar).
Map<String, Object> lockFields(Invitation inv, {required String origDate}) => {
      'type': inv.type,
      'theme': inv.theme,
      'n1': inv.n1,
      'n2': inv.n2,
      'date': inv.date,
      'origDate': origDate,
      'nameEdits': (kNameEdits - inv.nameEditsLeft).clamp(0, kNameEdits),
      'dateEdits': (kDateEdits - inv.dateEditsLeft).clamp(0, kDateEdits),
    };

/// Yeni belge alanları (createdAt hariç — servis serverTimestamp ekler; tarihler DateTime, servis Timestamp'e çevirir).
Map<String, Object> newInviteFields({
  required String ownerUid,
  required String plan,
  required String dataJson,
  required DateTime expiresAt,
  required Map<String, Object> lock,
}) =>
    {
      'ownerUid': ownerUid,
      'schema': kInviteSchema,
      'data': dataJson,
      'plan': plan,
      'status': 'live',
      'expiresAt': expiresAt,
      'deleteAt': deleteAtFor(expiresAt),
      ...lock,
    };

/// Kurallardaki keys().hasOnly listesiyle aynı.
const List<String> kInviteDocKeys = [
  'ownerUid', 'schema', 'data', 'plan', 'status', 'createdAt', 'expiresAt', 'deleteAt', //
  'type', 'theme', 'n1', 'n2', 'date', 'origDate', 'nameEdits', 'dateEdits',
];

String storagePath(String id, String file) => '$kInvitesCollection/$id/$file';

String extForMime(String mime) {
  switch (mime) {
    case 'image/webp':
      return 'webp';
    case 'image/png':
      return 'png';
    case 'image/gif':
      return 'gif';
    default:
      return 'jpg';
  }
}

/// 'cover' ya da 'g1'…'g6'.
String storageFileName(String slot, String mime) => '$slot.${extForMime(mime)}';

/// Galeri için boş yuva (g1…g6), kullanılan Storage yollarına göre. Yer yoksa null.
String? freeGallerySlot(String id, Iterable<String> usedPaths) {
  final used = usedPaths.toSet();
  for (var i = 1; i <= 6; i++) {
    final prefix = storagePath(id, 'g$i.');
    if (!used.any((p) => p.startsWith(prefix))) return 'g$i';
  }
  return null;
}

/// Şu an yayında ve süresi dolmamış ücretsiz davetiye sayısı.
int activeFreeCount(Iterable<Invitation> invs, DateTime now, {String? exceptId}) => invs
    .where((i) =>
        i.id != exceptId && i.isLive && i.cloudId != null && i.plan == 'free' && !i.isExpiredAt(now))
    .length;
