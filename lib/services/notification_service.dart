import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// SharedPreferences key for the global alarm-sound on/off toggle, shared
  /// by the wellness reminders and the home tab's wake alarm.
  static const soundPrefKey = 'notif_sound';

  // Android ties a channel's sound to the channel forever once it's first
  // created, so "sound on/off" needs two distinct channels to actually
  // change behavior rather than one channel with a mutable `sound` field.
  static const _channelIdSound = 'wellness_reminders';
  static const _channelIdSilent = 'wellness_reminders_silent';
  static const _channelName = 'Wellness Reminders';
  static const int _morningId = 101;
  static const int _eveningId = 102;
  static const int _wakeAlarmId = 103;
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

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

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
    await scheduleWakeAlarm(
      enabled: prefs.getBool('wake_alarm_on') ?? true,
      hour: prefs.getInt('wake_alarm_hour') ?? 8,
      minute: prefs.getInt('wake_alarm_minute') ?? 30,
      sound: sound,
    );
    await scheduleSessionReminder(
      enabled: prefs.getBool('notif_session') ?? true,
      sound: sound,
    );
  }

  static Future<void> scheduleMorning({bool enabled = true, bool sound = true}) async {
    if (!enabled) {
      await _plugin.cancel(_morningId);
      return;
    }
    await _plugin.zonedSchedule(
      _morningId,
      'Morning Wellness Check-in',
      'Log your Sleep data & Overall Recovery Metrics to stay on top of recovery.',
      _nextInstanceOf(7, 30),
      _details(sound: sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleEvening({bool enabled = true, bool sound = true}) async {
    if (!enabled) {
      await _plugin.cancel(_eveningId);
      return;
    }
    await _plugin.zonedSchedule(
      _eveningId,
      'Evening Load Reminder',
      "Don't forget to log today's training & skill Load before the day ends.",
      _nextInstanceOf(20, 0),
      _details(sound: sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Daily wake alarm set from the home screen's Tonight's Sleep card.
  /// Repeats at the same clock time each day, like the other reminders.
  static Future<void> scheduleWakeAlarm({
    required bool enabled,
    int hour = 8,
    int minute = 30,
    bool sound = true,
  }) async {
    if (!enabled) {
      await _plugin.cancel(_wakeAlarmId);
      return;
    }
    await _plugin.zonedSchedule(
      _wakeAlarmId,
      'Wake up',
      'Time to get up — log last night’s sleep while it is fresh.',
      _nextInstanceOf(hour, minute),
      _details(sound: sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Daily reminder to log a training/skill session, enabled by default so
  /// it works out of the box without the user having to visit settings.
  static Future<void> scheduleSessionReminder({bool enabled = true, bool sound = true}) async {
    if (!enabled) {
      await _plugin.cancel(_sessionId);
      return;
    }
    await _plugin.zonedSchedule(
      _sessionId,
      'Session Reminder',
      "Don't forget to log today's training session.",
      _nextInstanceOf(18, 0),
      _details(sound: sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Fires an immediate notification through the same channel as the
  /// wellness reminders, so a user can confirm delivery actually works on
  /// their device without waiting for the next scheduled time.
  static Future<void> showTestNotification({bool sound = true}) => _plugin.show(
        999,
        'Test Notification',
        "If you can see this, notifications are working on your device.",
        _details(sound: sound),
      );

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
