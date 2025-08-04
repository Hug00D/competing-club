import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  /// ✅ 初始化通知（main.dart 呼叫一次）
  static Future<void> init() async {
    tz.initializeTimeZones();

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

  /// ✅ 測試通知（立即跳出）
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      '主要通知頻道',
      channelDescription: 'APP 的所有通知都會使用這個頻道',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // 🔥 讓通知像鬧鐘一樣跳出
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      999,
      '✅ 測試通知',
      '這是立刻跳出的通知',
      notificationDetails,
    );
  }

  static final Map<int, DateTime> _scheduledTimes = {};

  /// ✅ 共用通知設定（含 Full-Screen Intent）
  static const AndroidNotificationDetails _androidDetails =
  AndroidNotificationDetails(
    'main_channel',
    '主要通知頻道',
    channelDescription: 'APP 的所有通知都會使用這個頻道',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true, // 🔥 讓通知可以喚醒螢幕
    icon: '@mipmap/ic_launcher',
  );

  /// ✅ 精準排程（Exact Allow While Idle 模式）
  static Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      if (scheduledTime.isBefore(DateTime.now())) {
        scheduledTime = DateTime.now().add(const Duration(seconds: 5));
        debugPrint('⚠️ [Exact] 時間太近，自動往後延 5 秒 → $scheduledTime');
      }

      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      _scheduledTimes[id] = scheduledTime;

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('✅ [Exact] 已排程通知於: $scheduledTime');
      await _debugPending();
    } catch (e) {
      debugPrint('❌ [Exact] 錯誤: $e');
    }
  }

  /// ✅ 像鬧鐘一樣的排程（Alarm Clock 模式）
  static Future<void> scheduleAlarmClockNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      if (scheduledTime.isBefore(DateTime.now())) {
        scheduledTime = DateTime.now().add(const Duration(seconds: 5));
        debugPrint('⚠️ [AlarmClock] 時間太近，自動往後延 5 秒 → $scheduledTime');
      }

      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      _scheduledTimes[id] = scheduledTime;

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );

      debugPrint('✅ [AlarmClock] 已排程通知於: $scheduledTime');
      await _debugPending();
    } catch (e) {
      debugPrint('❌ [AlarmClock] 錯誤: $e');
    }
  }

  /// ✅ 取消單一通知
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// ✅ 取消所有通知
  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// ✅ Debug：檢查目前排程的通知
  static Future<void> _debugPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('📋 當前排程的通知數量: ${pending.length}');
    for (final p in pending) {
      debugPrint(
        '🔔 ID=${p.id}, 標題=${p.title}, ➡ 預計時間: ${_scheduledTimes[p.id] ?? "未知"}',
      );
    }
  }

  /// ✅ 開啟精準鬧鐘權限設定頁面（Android 12+）
  static Future<void> requestExactAlarmPermission() async {
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }
}
