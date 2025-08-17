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

  // 頻道
  static const String _channelId = 'main_channel';
  static const String _channelName = '主要通知頻道';
  static const String _channelDesc = '一般提醒、AI 回覆與任務提醒';

  // 點擊通知的外部 handler（由 main.dart 註冊）
  static void Function(String payload)? onTap;
  static void setOnTapHandler(void Function(String payload) handler) {
    onTap = handler;
  }

  // === 初始化 ===
  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTapForeground,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    debugPrint('🕒 tz.local=${tz.local}, now=${DateTime.now()}');
  }

  static void _onTapForeground(NotificationResponse resp) {
    debugPrint('🔔(fg) tap id=${resp.id} payload=${resp.payload}');
    if (onTap != null && resp.payload != null) onTap!(resp.payload!);
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse resp) {
    debugPrint('🔔(bg) tap id=${resp.id} payload=${resp.payload}');
    if (onTap != null && resp.payload != null) onTap!(resp.payload!);
  }

  static Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
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
    visibility: NotificationVisibility.public,
  );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const NotificationDetails _platformDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
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

  // === 單次排程（新版：一定要給 androidScheduleMode） ===
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
      matchDateTimeComponents: null,
    );
    debugPrint('✅ [Exact] $id @ $fixed');
    await debugPending();
  }

  /// Alarm Clock（會在系統時鐘顯示鬧鐘圖示）
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
      matchDateTimeComponents: null,
    );
    debugPrint('✅ [AlarmClock] $id @ $fixed');
    await debugPending();
  }

  /// 保底邏輯（在新版等同呼叫一次 exact；需要更強保底，可自行加第二筆 alarmClock）
  static Future<void> scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    await scheduleExact(
      id: id,
      title: title,
      body: body,
      when: when,
      payload: payload,
    );
  }

  // === 重複排程（每日／每週） ===
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
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('✅ [Daily] $id @ $next');
    await debugPending();
  }

  static Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1=Mon ... 7=Sun
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
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
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

  // === Helpers ===
  static DateTime _normalizeFutureTime(DateTime when) {
    final now = DateTime.now();
    // 避免「立刻或過去」造成錯過排程 → 至少 +2 秒
    if (!when.isAfter(now.add(const Duration(seconds: 1)))) {
      return now.add(const Duration(seconds: 2));
    }
    return when;
  }

  static tz.TZDateTime _nextDailyTime(
      tz.TZDateTime now, int hour, int minute) {
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  /// weekday: 1=Mon ... 7=Sun
  static tz.TZDateTime _nextWeeklyTime(
      tz.TZDateTime now, int weekday, int hour, int minute) {
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

  // === Backward-compat 別名（給舊呼叫保留） ===
  static Future<void> requestExactAlarmPermission() =>
      openExactAlarmSettings();

  static Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) =>
      scheduleExact(
        id: id,
        title: title,
        body: body,
        when: scheduledTime,
        payload: payload,
      );

  static Future<void> scheduleAlarmClockNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) =>
      scheduleAlarmClock(
        id: id,
        title: title,
        body: body,
        when: scheduledTime,
        payload: payload,
      );
}
