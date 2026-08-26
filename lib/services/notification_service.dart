import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// SharedPreferences key for the global alarm-sound on/off toggle, shared
  /// by the wellness reminders.
  static const soundPrefKey = 'notif_sound';

  // Android ties a channel's sound to the channel forever once it's first
  // created, so "sound on/off" needs two distinct channels to actually
  // change behavior rather than one channel with a mutable `sound` field.
  static const _channelIdSound = 'wellness_reminders';
  static const _channelIdSilent = 'wellness_reminders_silent';
  static const _channelName = 'Wellness Reminders';
  static const int _morningId = 101;
  static const int _eveningId = 102;
  // 103 was the removed wake-alarm feature's id — cancelled below on every
  // startup so a device that had it scheduled before this update doesn't
  // keep firing it forever (AlarmManager entries outlive the app code that
  // scheduled them).
  static const int _removedWakeAlarmId = 103;
  static const int _sessionId = 104;

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

  /// Re-arms all reminders from their last saved settings. Needed on every
  /// app start (not just when a toggle is touched) because Android/OEM
  /// battery managers can force-stop the app, which silently wipes every
  /// AlarmManager entry the app had registered.
  static Future<void> scheduleAll() async {
    final prefs = await SharedPreferences.getInstance();
    final sound = prefs.getBool(soundPrefKey) ?? true;
    await scheduleMorning(
      enabled: prefs.getBool('notif_morning') ?? true,
      sound: sound,
    );
    await scheduleEvening(
      enabled: prefs.getBool('notif_evening') ?? true,
      sound: sound,
    );
    await scheduleSessionReminder(
      enabled: prefs.getBool('notif_session') ?? true,
      sound: sound,
    );
    await _plugin.cancel(_removedWakeAlarmId);
  }

  static Future<void> scheduleMorning({bool enabled = true, bool sound = true}) async {
    if (!enabled) {
      await _plugin.cancel(_morningId);
      return;
    }
    await _zonedSchedule(
      _morningId,
      'Morning Wellness Check-in',
      'Log your Sleep data & Overall Recovery Metrics to stay on top of recovery.',
      _nextInstanceOf(7, 30),
      sound: sound,
    );
  }

  static Future<void> scheduleEvening({bool enabled = true, bool sound = true}) async {
    if (!enabled) {
      await _plugin.cancel(_eveningId);
      return;
    }
    await _zonedSchedule(
      _eveningId,
      'Evening Load Reminder',
      "Don't forget to log today's training & skill Load before the day ends.",
      _nextInstanceOf(20, 0),
      sound: sound,
    );
  }

  /// Daily reminder to log a training/skill session, enabled by default so
  /// it works out of the box without the user having to visit settings.
  static Future<void> scheduleSessionReminder({bool enabled = true, bool sound = true}) async {
    if (!enabled) {
      await _plugin.cancel(_sessionId);
      return;
    }
    await _zonedSchedule(
      _sessionId,
      'Session Reminder',
      "Don't forget to log today's training session.",
      _nextInstanceOf(18, 0),
      sound: sound,
    );
  }

  /// Schedules with exact timing, falling back to an inexact (OS-batched,
  /// within-~15-min) alarm if exact scheduling is rejected — e.g. the user
  /// never granted "Alarms & reminders" on Android 12+. Without this
  /// fallback a denied exact-alarm permission throws here and silently
  /// cancels scheduling for every reminder still to come in scheduleAll().
  static Future<void> _zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime when, {
    required bool sound,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details(sound: sound),
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
        _details(sound: sound),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static NotificationDetails _details({bool sound = true}) => NotificationDetails(
        android: AndroidNotificationDetails(
          sound ? _channelIdSound : _channelIdSilent,
          sound ? _channelName : '$_channelName (Silent)',
          channelDescription: 'Daily reminders to log your wellness metrics',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          sound: sound ? const RawResourceAndroidNotificationSound('alarm_sound') : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: sound,
          sound: sound ? 'alarm_sound.wav' : null,
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
