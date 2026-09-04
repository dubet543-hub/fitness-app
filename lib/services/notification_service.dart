import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // Both reminders always play sound — there's no separate toggle for it.
  static const _channelIdSound = 'wellness_reminders';
  static const _channelName = 'Wellness Reminders';
  static const int _morningId = 101;
  static const int _eveningId = 102;
  // 103 and 104 were the removed wake-alarm and session-reminder features'
  // ids — cancelled below on every startup so a device that had either
  // scheduled before this update doesn't keep firing it forever
  // (AlarmManager entries outlive the app code that scheduled them).
  static const int _removedWakeAlarmId = 103;
  static const int _removedSessionReminderId = 104;

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Each Android permission request is independently guarded — one denial
    // or plugin exception (both real on some OEM ROMs) must not stop the
    // others, and must never prevent scheduleAll() below from running. Before
    // this was one unguarded call away from silently disabling every
    // reminder on Android with no error, while iOS's simpler init path never
    // touches any of these and so was unaffected.
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}

    // Android 12+ revokes exact-alarm scheduling by default, and OEM battery
    // managers (Xiaomi/vivo/Oppo/etc.) kill backgrounded apps outright unless
    // exempted — either one silently drops every reminder below with no error,
    // so both are requested proactively at startup rather than left for the
    // user to discover and fix manually.
    if (Platform.isAndroid) {
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {}
      try {
        await Permission.ignoreBatteryOptimizations.request();
      } catch (_) {}
    }

    await scheduleAll();
  }

  /// Re-arms both reminders from their last saved settings. Needed on every
  /// app start (not just when a toggle is touched) because Android/OEM
  /// battery managers can force-stop the app, which silently wipes every
  /// AlarmManager entry the app had registered.
  static Future<void> scheduleAll() async {
    final prefs = await SharedPreferences.getInstance();
    await scheduleMorning(enabled: prefs.getBool('notif_morning') ?? true);
    await scheduleEvening(enabled: prefs.getBool('notif_evening') ?? true);
    try { await _plugin.cancel(_removedWakeAlarmId); } catch (_) {}
    try { await _plugin.cancel(_removedSessionReminderId); } catch (_) {}
  }

  static Future<void> scheduleMorning({bool enabled = true}) async {
    if (!enabled) {
      // Guarded like every other plugin call in this file — a cancel
      // failure here must not stop scheduleAll() from reaching the
      // reminders still to come.
      try { await _plugin.cancel(_morningId); } catch (_) {}
      return;
    }
    await _zonedSchedule(
      _morningId,
      'Morning Wellness Check-in',
      'Log your Sleep data & Overall Recovery Metrics to stay on top of recovery.',
      _nextInstanceOf(7, 30),
    );
  }

  static Future<void> scheduleEvening({bool enabled = true}) async {
    if (!enabled) {
      try { await _plugin.cancel(_eveningId); } catch (_) {}
      return;
    }
    await _zonedSchedule(
      _eveningId,
      'Evening Load Reminder',
      "Don't forget to log today's training & skill Load before the day ends.",
      _nextInstanceOf(20, 0),
    );
  }

  // TEMPORARY — for on-device verification only (sound, channel, permission
  // all work end-to-end); remove once the notification fixes are confirmed
  // on real Android hardware.
  static Future<void> showTestNotification() =>
      _plugin.show(999, 'Test Notification',
          'If you can see and hear this, notifications are working.', _details);

  /// Schedules with exact timing, falling back to an inexact (OS-batched,
  /// within-~15-min) alarm if exact scheduling is rejected — e.g. the user
  /// never granted "Alarms & reminders" on Android 12+. Without this
  /// fallback a denied exact-alarm permission throws here and silently
  /// cancels scheduling for every reminder still to come in scheduleAll().
  static Future<void> _zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static final NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelIdSound,
      _channelName,
      channelDescription: 'Daily reminders to log your wellness metrics',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
    ),
    iOS: const DarwinNotificationDetails(
      presentSound: true,
      sound: 'alarm_sound.wav',
    ),
  );

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
