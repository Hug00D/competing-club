import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // ✅ for debugPrint

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  /// ✅ 初始化通知（在 main.dart 呼叫一次）
  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    await _requestPermission();
  }

  /// ✅ Android 13+ / iOS 通知權限
  static Future<void> _requestPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  /// ✅ 測試通知（立刻跳出）
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      '測試通知頻道',
      channelDescription: '這個頻道用於測試通知功能',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      999,
      '✅ 測試通知',
      '這是立刻跳出的通知',
      notificationDetails,
    );
  }

  /// ✅ 排程通知（吃藥提醒 / 鬧鐘）
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      '任務提醒',
      channelDescription: '排程通知，例如吃藥提醒',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    debugPrint('✅ 已排程通知於: $scheduledTime');
  }

  /// ✅ 取消單一通知
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// ✅ 取消所有通知
  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}
