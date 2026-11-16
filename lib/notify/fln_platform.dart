import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_platform.dart';

/// flutter_local_notifications uygulaması. Zaman, UTC bölgesinde mutlak an olarak verilir
/// (tekrarlayan bildirim yok → yerel saat dilimi veritabanı gerekmez).
class FlnPlatform implements ReminderPlatform {
  static const String channelId = 'zarfla_reminders';
  static const String smallIcon = 'ic_stat_zarfla';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<String?> init(void Function(String? payload) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(smallIcon)),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload),
    );
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d != null && d.didNotificationLaunchApp) return d.notificationResponse?.payload;
    return null;
  }

  @override
  Future<bool> notificationsEnabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('zarfla: areNotificationsEnabled failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('zarfla: requestNotificationsPermission failed: $e');
      return false;
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required int atMs,
    required String payload,
    required String channelName,
    required String channelDesc,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, atMs),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          icon: smallIcon,
          category: AndroidNotificationCategory.reminder,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      // Yaklaşık zamanlama: SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM izni GEREKMEZ.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
