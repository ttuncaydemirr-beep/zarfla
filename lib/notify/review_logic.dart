/// Uygulama içi değerlendirme istemi — SAF mantık (eklentiden bağımsız; birim testli).
///
/// Play politikası: "Beğendiniz mi?" ön sorusu yok, düğme/ödül bağlama yok; yalnız net bir başarı anından
/// sonra, nadiren, sistemin kendi penceresi. Burada: ücretli yayından sonra YA DA ikinci paylaşımdan sonra,
/// son istemden en az [kReviewMinGap] sonra, ilk açılışın hemen ardından değil.
library;

/// Bu kadar paylaşımdan sonra (WhatsApp açıldı) başarı anı sayılır.
const int kReviewShareThreshold = 2;

/// İki istem arası en az süre.
const Duration kReviewMinGap = Duration(days: 90);

/// İlk açılıştan en az bu kadar sonra (ilk oturumun hemen ardından istenmez).
const Duration kReviewMinAge = Duration(hours: 1);

/// Değerlendirme istemi gösterilmeli mi?
/// - [firstLaunchMs]: ilk açılış (bilinmiyorsa istenmez),
/// - [lastPromptMs]: son istem (yoksa null); saat geriye alınmışsa (gelecekte) güvenli tarafta kalınır,
/// - [shareCount]: tamamlanan paylaşım sayısı, [paidPublish]: bu oturumda ücretli yayın/yükseltme oldu.
bool shouldPromptReview({
  required int nowMs,
  required int? firstLaunchMs,
  required int? lastPromptMs,
  required int shareCount,
  required bool paidPublish,
}) {
  if (firstLaunchMs == null || firstLaunchMs > nowMs) return false;
  if (nowMs - firstLaunchMs < kReviewMinAge.inMilliseconds) return false;
  if (lastPromptMs != null && (lastPromptMs > nowMs || nowMs - lastPromptMs < kReviewMinGap.inMilliseconds)) return false;
  return paidPublish || shareCount >= kReviewShareThreshold;
}
