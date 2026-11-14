import '../models/invitation.dart';

/// Eski sürümlerin alan ipuçlarındaki örnek kişi adları ve aile adları. Kullanıcı bunları
/// kendisi yazmadıysa (otomatik doldurulmuşsa) açılışta bir kez temizlenir; yalnız BİREBİR eşleşmeler.
/// Bu dosya, Türkçe karakter denetiminin açık istisnasıdır (test/no_hardcoded_text_test.dart).
const Set<String> kLegacySampleNames = {
  'Pelin Su', 'Pelin', 'Burak', 'Ayşe Yılmaz', 'Ali Kerem', 'Deniz', 'Elif', 'Kaan',
  'Emma', 'James', 'Leo', 'Lena', 'Jonas', 'Paul', 'Sarah Johnson', 'Anna Schmidt',
  'سارة', 'أحمد', 'يوسف', 'نورة محمد',
};

const Set<String> kLegacySampleHosts = {
  'Demir ve Yılmaz aileleri',
  'Miller and Smith families',
  'The Miller and Smith families',
  'Familien Weber und Yılmaz',
  'عائلتا الأحمد والسالم',
};

/// Taslaktaki birebir örnek adları/aile adını temizler. Değişiklik olduysa true.
/// Yayındaki davetiyelere dokunulmaz (bulutla eşleşmeleri bozulmasın).
bool clearSampleNames(Invitation inv) {
  if (inv.isLive) return false;
  var changed = false;
  if (kLegacySampleNames.contains(inv.n1)) {
    inv.n1 = '';
    changed = true;
  }
  if (kLegacySampleNames.contains(inv.n2)) {
    inv.n2 = '';
    changed = true;
  }
  if (kLegacySampleHosts.contains(inv.host)) {
    inv.host = '';
    changed = true;
  }
  return changed;
}
