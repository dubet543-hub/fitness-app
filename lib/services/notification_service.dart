import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'wellness_reminders';
  static const _channelName = 'Wellness Reminders';
  static const int _morningId = 101;
  static const int _eveningId = 102;

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

  static Future<void> scheduleAll() async {
    await scheduleMorning();
    await scheduleEvening();
  }

  static Future<void> scheduleMorning({bool enabled = true}) async {
    if (!enabled) {
      await _plugin.cancel(_morningId);
      return;
    }
    await _plugin.zonedSchedule(
      _morningId,
      'Morning Wellness Check-in',
      'Log your Sleep, Readiness, Soreness & Fatigue to stay on top of recovery.',
      _nextInstanceOf(7, 0),
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleEvening({bool enabled = true}) async {
    if (!enabled) {
      await _plugin.cancel(_eveningId);
      return;
    }
    await _plugin.zonedSchedule(
      _eveningId,
      'Evening Wellness Reminder',
      "Don't forget to log today's wellness data before the day ends.",
      _nextInstanceOf(20, 0),
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Daily reminders to log your wellness metrics',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
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
