import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart'; // ✅ for Android 設定頁

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  /// ✅ 初始化通知（在 main.dart 呼叫一次）
  static Future<void> init() async {
    // 初始化時區資料（一定要有）
    tz.initializeTimeZones();

    // ❌ 不要強制 Asia/Taipei，改用系統時區
    // tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    // ✅ iOS / Android 13+ 要先要通知權限
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
  /// [useExact] = true → 精準鬧鐘（需要額外權限）
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool useExact = false,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'task_channel',
        '任務提醒',
        channelDescription: '排程通知，例如吃藥提醒',
        importance: Importance.max,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      // 🔍 如果時間小於 1 分鐘 → 自動補成「現在 + 1 分鐘」
      if (scheduledTime.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
        scheduledTime = DateTime.now().add(const Duration(minutes: 1));
        debugPrint('⏩ 時間太近，自動延後到：$scheduledTime');
      }

      // ✅ 用系統時區 (tz.local) 轉換 scheduledTime
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      debugPrint('📅 要排程的時間 (tz): $tzTime / 原始: $scheduledTime');

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        notificationDetails,
        androidScheduleMode: useExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );

      debugPrint('✅ 已排程通知於: $scheduledTime (模式: ${useExact ? "精準" : "一般"})');
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException: ${e.code} | ${e.message}');
    } catch (e) {
      debugPrint('❌ 其他錯誤: $e');
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

  /// ✅ Android 12+ 導引用戶去開啟精準鬧鐘權限
  static Future<void> requestExactAlarmPermission() async {
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }
}
