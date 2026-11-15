import '../data/catalog.dart';
import '../models/invitation.dart';
import 'date_utils.dart';

/// Yayın sonrası kilit kuralları — YALNIZ ücretli (premium) ve yayında olan davetiyelerde:
/// - etkinlik türü ve tasarım değiştirilemez,
/// - isimlerde toplam 3 düzeltme,
/// - tarihte 2 değişiklik; yeni tarih ilk (yayın anındaki) tarihten en fazla ±60 gün.
const int kNameEdits = 3;
const int kDateEdits = 2;
const int kDateWindowDays = 60;

bool isLocked(Invitation inv) => inv.status == 'live' && inv.plan == 'premium';

/// Bu davetiye ücretli olacak/ücretli mi? (Hediye IBAN'ı bölümü yalnız bunlarda açıktır.)
/// Yayındaysa plan belirler; taslakta ücretli tasarım seçilmişse ücretli sayılır (ücretli tasarım zaten
/// ücretsiz yayınlanamaz). Ücretsiz tasarımlı taslakta plan yayın ekranında seçildiği için bölüm kilitli görünür.
bool isPaidInvite(Invitation inv) =>
    inv.plan == 'premium' || (inv.status != 'live' && (kThemes[inv.theme]?.premium ?? false));

bool canChangeTypeOrTheme(Invitation inv) => !isLocked(inv);

/// Ücretsiz yayındaki (süresi dolmuş olsa da) davetiye "1 Davetiye Hakkı" ile AYNI bağlantıda ücretliye
/// yükseltilebilir: sunucu (redeemPurchase) aynı belge kimliğini ücretli yazar, süre yeniden 1 yıl olur.
/// Belge deleteAt'e (süre + 30 gün) kadar durur; sonrasında da aynı kimlikle yeniden oluşturulur.
bool canUpgradeToPaid(Invitation inv) => inv.status == 'live' && inv.plan == 'free' && inv.cloudId != null;

enum EditOutcome { applied, unchanged, noRightsLeft, empty, outOfRange }

/// Yayınla: plan 'free' | 'premium'. Ücretli yayında haklar ve ilk tarih sıfırlanır.
void markPublished(Invitation inv, String plan) {
  inv.status = 'live';
  inv.plan = plan;
  if (plan == 'premium') {
    inv.nameEditsLeft = kNameEdits;
    inv.dateEditsLeft = kDateEdits;
    inv.originalDate = inv.date;
  }
}

/// İsim düzenleme. Kilitli değilse doğrudan uygular.
EditOutcome applyNameEdit(Invitation inv, {required bool first, required String value}) {
  if (!isLocked(inv)) {
    if (first) {
      inv.n1 = value;
    } else {
      inv.n2 = value;
    }
    return EditOutcome.applied;
  }
  final v = value.trim();
  final old = (first ? inv.n1 : inv.n2).trim();
  if (v == old) return EditOutcome.unchanged;
  if (inv.nameEditsLeft <= 0) return EditOutcome.noRightsLeft;
  if (v.isEmpty) return EditOutcome.empty;
  if (first) {
    inv.n1 = v;
  } else {
    inv.n2 = v;
  }
  inv.nameEditsLeft -= 1;
  return EditOutcome.applied;
}

/// Kilitli davetiyede izin verilen tarih aralığı (min, max) ya da null.
(String, String)? dateWindow(Invitation inv) {
  if (!isLocked(inv)) return null;
  final orig = (inv.originalDate == null || inv.originalDate!.isEmpty) ? inv.date : inv.originalDate!;
  if (orig.isEmpty) return null;
  return (shiftIsoDate(orig, -kDateWindowDays), shiftIsoDate(orig, kDateWindowDays));
}

/// Tarih değiştirme. Kilitli değilse doğrudan uygular.
EditOutcome applyDateEdit(Invitation inv, String value) {
  if (!isLocked(inv)) {
    inv.date = value;
    return EditOutcome.applied;
  }
  if (value == inv.date) return EditOutcome.unchanged;
  if (inv.dateEditsLeft <= 0) return EditOutcome.noRightsLeft;
  final w = dateWindow(inv);
  if (value.isEmpty || parseIsoDate(value) == null) return EditOutcome.outOfRange;
  if (w != null && (value.compareTo(w.$1) < 0 || value.compareTo(w.$2) > 0)) {
    return EditOutcome.outOfRange;
  }
  inv.date = value;
  inv.dateEditsLeft -= 1;
  return EditOutcome.applied;
}
