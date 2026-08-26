import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _morningReminder = true;
  bool _eveningReminder = true;
  bool _alarmSound = true;
  bool sessionReminders = true;
  bool weeklySummary    = false;
  bool pushNotifications = true;
  bool emailDigest      = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morningReminder = prefs.getBool('notif_morning') ?? true;
      _eveningReminder = prefs.getBool('notif_evening') ?? true;
      _alarmSound      = prefs.getBool(NotificationService.soundPrefKey) ?? true;
      sessionReminders = prefs.getBool('notif_session') ?? true;
    });
  }

  Future<void> _setMorning(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_morning', v);
    await NotificationService.scheduleMorning(enabled: v, sound: _alarmSound);
    setState(() => _morningReminder = v);
  }

  Future<void> _setEvening(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_evening', v);
    await NotificationService.scheduleEvening(enabled: v, sound: _alarmSound);
    setState(() => _eveningReminder = v);
  }

  /// Applies to the wellness reminders above.
  Future<void> _setAlarmSound(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.soundPrefKey, v);
    await NotificationService.scheduleMorning(enabled: _morningReminder, sound: v);
    await NotificationService.scheduleEvening(enabled: _eveningReminder, sound: v);
    await NotificationService.scheduleSessionReminder(enabled: sessionReminders, sound: v);
    setState(() => _alarmSound = v);
  }

  Future<void> _setSessionReminders(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_session', v);
    await NotificationService.scheduleSessionReminder(enabled: v, sound: _alarmSound);
    setState(() => sessionReminders = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('NOTIFICATIONS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: IconThemeData(color: kTextPrimary),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _SectionLabel('WELLNESS REMINDERS'),
          const SizedBox(height: 8),
          _ToggleGroup(items: [
            _ToggleItem(
              title: 'Morning check-in',
              subtitle: '7:00 AM · Sleep, Readiness, Soreness & Fatigue',
              value: _morningReminder,
              onChanged: _setMorning,
            ),
            _ToggleItem(
              title: 'Evening reminder',
              subtitle: "8:00 PM · Log today's wellness data",
              value: _eveningReminder,
              onChanged: _setEvening,
            ),
            _ToggleItem(
              title: 'Alarm sound',
              subtitle: 'Play a sound with wellness reminders',
              value: _alarmSound,
              onChanged: _setAlarmSound,
            ),
          ]),
          const SizedBox(height: 20),

          _SectionLabel('ACTIVITY'),
          const SizedBox(height: 8),
          _ToggleGroup(items: [
            _ToggleItem(title: 'Session reminders', subtitle: '6:00 PM · Log today\'s training session',
              value: sessionReminders, onChanged: _setSessionReminders),
            _ToggleItem(title: 'Weekly summary', subtitle: 'Performance recap every Monday',
              value: weeklySummary, onChanged: (v) => setState(() => weeklySummary = v)),
          ]),
          const SizedBox(height: 20),

          _SectionLabel('DELIVERY'),
          const SizedBox(height: 8),
          _ToggleGroup(items: [
            _ToggleItem(title: 'Push notifications', subtitle: 'On this device',
              value: pushNotifications, onChanged: (v) => setState(() => pushNotifications = v)),
            _ToggleItem(title: 'Email digest', subtitle: 'Weekly email roundup',
              value: emailDigest, onChanged: (v) => setState(() => emailDigest = v)),
          ]),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: kTextSecondary),
  );
}

class _ToggleGroup extends StatelessWidget {
  final List<_ToggleItem> items;
  const _ToggleGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (i) => Column(children: [
          items[i],
          if (i < items.length - 1) Divider(height: 1, indent: 16, color: kBorder),
        ])),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: kTextSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: kAccent,
            activeTrackColor: kAccent.withValues(alpha: 0.25),
            inactiveThumbColor: kTextMuted,
            inactiveTrackColor: kBorderBright,
          ),
        ],
      ),
    );
  }
}
