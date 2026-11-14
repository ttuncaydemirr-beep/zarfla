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

bool canChangeTypeOrTheme(Invitation inv) => !isLocked(inv);

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
