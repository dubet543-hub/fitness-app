import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../widgets/common_widgets.dart' show SectionHeader;

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
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
        children: [
          const _SectionLabel('Reminders'),
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
          const SizedBox(height: 24),
          // TEMPORARY — on-device verification only, remove once confirmed.
          OutlinedButton.icon(
            onPressed: () { hapticSelect(); NotificationService.showTestNotification(); },
            icon: const Icon(Icons.notifications_none_rounded, size: 20, color: kTextSecondary),
            label: const Text('Send test notification'),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: SectionHeader(text),
  );
}

class _ToggleGroup extends StatelessWidget {
  final List<_ToggleItem> items;
  const _ToggleGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorder, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 0.6, thickness: 0.6, indent: 16, color: kBorder),
            items[i],
          ],
        ],
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
    void toggle(bool v) { hapticSelect(); onChanged(v); }
    return InkWell(
      onTap: () => toggle(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kTextPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: toggle),
          ],
        ),
      ),
    );
  }
}
