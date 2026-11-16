/// Bildirim katmanı arayüzü: orkestra ([Reminders]) yalnız bunu bilir, böylece testlerde sahtesi kullanılır
/// ve eklenti sürümüne özgü API tek dosyada ([FlnPlatform]) kalır.
abstract class ReminderPlatform {
  /// Eklentiyi başlatır (izin İSTEMEZ). [onTap]: bildirime dokunma (yük). Uygulama bildirimle açıldıysa
  /// dönen değer o bildirimin yüküdür.
  Future<String?> init(void Function(String? payload) onTap);

  /// Bildirim gösterilebilir mi? (Android 13+ izni verilmediyse false; eski sürümlerde true.)
  Future<bool> notificationsEnabled();

  /// Bildirim iznini ister (Android 13+ sistem penceresi). Verildi mi?
  Future<bool> requestPermission();

  /// [atMs] anında (YAKLAŞIK zamanlama: kesin alarm izni gerekmez) bildirimi zamanlar.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
    required String payload,
    required String channelName,
    required String channelDesc,
  });

  Future<void> cancel(int id);
}
