// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  // 頻道常數
  static const String _channelId = 'main_channel';
  static const String _channelName = '主要通知頻道';
  static const String _channelDesc = 'APP 的所有通知使用這個頻道';

  // === 初始化 ===
  static Future<void> init() async {
    // 1) 時區
    tz.initializeTimeZones();
    // （如需更嚴謹對齊裝置時區，可加 flutter_native_timezone_updated 並 setLocalLocation）

    // 2) 初始化設定
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTapForeground,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    // 3) Android 13+ / iOS 權限
    await _ensureNotificationPermission();

    debugPrint('🕒 tz.local=${tz.local}, now=${DateTime.now()}');
  }

  static void _onTapForeground(NotificationResponse resp) {
    debugPrint('🔔(fg) tap id=${resp.id} payload=${resp.payload}');
    // TODO: 導頁或處理 payload
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse resp) {
    debugPrint('🔔(bg) tap id=${resp.id} payload=${resp.payload}');
  }

  static Future<void> _ensureNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
    // iOS 權限已在 DarwinInitializationSettings 請求
  }

  /// 導去 Android 精準鬧鐘授權頁（Exact Alarm）
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    const intent =
    AndroidIntent(action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM');
    await intent.launch();
  }

  // === 樣式 ===
  static const AndroidNotificationDetails _androidDetails =
  AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true, // 類鬧鐘彈出效果
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _platformDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  // === 立即顯示 ===
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(id, title, body, _platformDetails, payload: payload);
  }

  // === 單次排程 ===

  /// 精準單次排程（exactAllowWhileIdle）
  static Future<void> scheduleExact({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    final fixed = _normalizeFutureTime(when);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fixed, tz.local),
      _platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    debugPrint('✅ [Exact] $id @ $fixed');
    await debugPending();
  }

  /// 鬧鐘式單次排程（alarmClock）
  static Future<void> scheduleAlarmClock({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    final fixed = _normalizeFutureTime(when);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fixed, tz.local),
      _platformDetails,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
    debugPrint('✅ [AlarmClock] $id @ $fixed');
    await debugPending();
  }

  /// ✅ 保底排程：先 exact，5 秒後仍 pending 就自動補一筆 alarmClock
  static Future<void> scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    await scheduleExact(id: id, title: title, body: body, when: when, payload: payload);

    // 等 5 秒，看看系統是否接受 / 觸發排程（在部分 AVD/裝置上 exact 會被延遲或吞）
    await Future.delayed(const Duration(seconds: 5));

    final pending = await _plugin.pendingNotificationRequests();
    final stillPending = pending.any((p) => p.id == id);
    debugPrint('🔎 fallback 檢查：id=$id stillPending=$stillPending (pending=${pending.length})');

    if (stillPending) {
      // 避免覆蓋，id 偏移 100000
      final fallbackId = id + 100000;
      await scheduleAlarmClock(
        id: fallbackId,
        title: title,
        body: '$body（保底）',
        when: when.add(const Duration(seconds: 2)),
        payload: payload,
      );
      debugPrint('🛟 已補排 AlarmClock：id=$fallbackId at $when');
      await debugPending();
    }
  }

  // === 重複排程 ===

  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final next = _nextDailyTime(now, hour, minute);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      _platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    debugPrint('✅ [Daily] $id @ $next');
    await debugPending();
  }

  static Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final next = _nextWeeklyTime(now, weekday, hour, minute);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      _platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
    debugPrint('✅ [Weekly] $id @ $next');
    await debugPending();
  }

  // === 取消 / 除錯 ===

  static Future<void> cancel(int id) => _plugin.cancel(id);

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> debugPending() async {
    final list = await _plugin.pendingNotificationRequests();
    debugPrint('📋 Pending=${list.length}');
    for (final p in list) {
      debugPrint('  • id=${p.id} title=${p.title}');
    }
  }

  // === Util ===

  /// 若時間已過，往後延 5 秒避免丟失
  static DateTime _normalizeFutureTime(DateTime when) {
    final now = DateTime.now();
    if (when.isBefore(now)) {
      final fixed = now.add(const Duration(seconds: 5));
      debugPrint('⚠️ when < now，改為 $fixed');
      return fixed;
    }
    return when;
  }

  static tz.TZDateTime _nextDailyTime(tz.TZDateTime now, int hour, int minute) {
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  /// weekday: 1=Mon ... 7=Sun
  static tz.TZDateTime _nextWeeklyTime(
      tz.TZDateTime now,
      int weekday,
      int hour,
      int minute,
      ) {
    var daysToAdd = (weekday - now.weekday) % 7;
    if (daysToAdd == 0) {
      final today =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (today.isAfter(now)) return today;
      daysToAdd = 7;
    }
    final date = now.add(Duration(days: daysToAdd));
    return tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);
  }

  // === Backward-compat 別名（如果舊程式有呼叫這些，會自動轉接） ===
  static Future<void> requestExactAlarmPermission() => openExactAlarmSettings();

  static Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) =>
      scheduleExact(id: id, title: title, body: body, when: scheduledTime, payload: payload);

  static Future<void> scheduleAlarmClockNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) =>
      scheduleAlarmClock(id: id, title: title, body: body, when: scheduledTime, payload: payload);
}
