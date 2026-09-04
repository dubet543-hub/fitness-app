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
    });
  }

  // Each setter flips the switch immediately (setState first) rather than
  // after awaiting the notification-plugin call — that call is best-effort
  // scheduling and can throw on some devices, and awaiting it before
  // setState left the switch visually stuck on its old position until the
  // page was reopened (which reloads from SharedPreferences, where the
  // value was already saved correctly) even though the tap itself "worked".

  Future<void> _setMorning(bool v) async {
    setState(() => _morningReminder = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_morning', v);
    try {
      await NotificationService.scheduleMorning(enabled: v);
    } catch (_) {}
  }

  Future<void> _setEvening(bool v) async {
    setState(() => _eveningReminder = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_evening', v);
    try {
      await NotificationService.scheduleEvening(enabled: v);
    } catch (_) {}
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
          _SectionLabel('REMINDERS'),
          const SizedBox(height: 8),
          _ToggleGroup(items: [
            _ToggleItem(
              title: 'Morning check-in',
              subtitle: '7:30 AM · Sleep, Readiness, Soreness & Fatigue',
              value: _morningReminder,
              onChanged: _setMorning,
            ),
            _ToggleItem(
              title: 'Evening reminder',
              subtitle: "8:00 PM · Log today's training & skill session",
              value: _eveningReminder,
              onChanged: _setEvening,
            ),
          ]),
          const SizedBox(height: 20),
          // TEMPORARY — on-device verification only, remove once confirmed.
          OutlinedButton.icon(
            onPressed: () => NotificationService.showTestNotification(),
            icon: Icon(Icons.notifications_active_rounded, size: 18, color: kAccent),
            label: Text('Send Test Notification',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: kAccent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
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
