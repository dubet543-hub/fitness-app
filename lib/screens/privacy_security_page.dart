import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../services/local_log_store.dart';

class PrivacySecurityPage extends StatefulWidget {
  /// Called after the account is deleted so the app can return to sign-in.
  final VoidCallback? onLoggedOut;
  const PrivacySecurityPage({super.key, this.onLoggedOut});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool twoFactor      = false;
  bool analyticsShare = true;
  bool dailyLogsConsent = true;
  bool cameraConsent    = true;

  static const _kTwoFactor = 'setting_two_factor';
  static const _kAnalytics = 'setting_analytics_share';

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final daily  = await LocalLogStore.dailyLogsConsent();
    final camera = await LocalLogStore.cameraConsent();
    final prefs  = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      dailyLogsConsent = daily;
      cameraConsent    = camera;
      twoFactor        = prefs.getBool(_kTwoFactor) ?? false;
      analyticsShare   = prefs.getBool(_kAnalytics) ?? true;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Change password', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (error != null) ...[
              Text(error!, style: TextStyle(color: Colors.redAccent, fontSize: 12.5)),
              const SizedBox(height: 10),
            ],
            _pwField(currentCtrl, 'Current password'),
            const SizedBox(height: 10),
            _pwField(newCtrl, 'New password'),
            const SizedBox(height: 10),
            _pwField(confirmCtrl, 'Confirm new password'),
          ]),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
            ),
            TextButton(
              onPressed: busy ? null : () async {
                if (newCtrl.text.length < 6) { setLocal(() => error = 'New password must be at least 6 characters'); return; }
                if (newCtrl.text != confirmCtrl.text) { setLocal(() => error = 'Passwords do not match'); return; }
                setLocal(() { busy = true; error = null; });
                try {
                  await ApiService.changePassword(currentPassword: currentCtrl.text, newPassword: newCtrl.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('Password updated');
                } catch (e) {
                  setLocal(() { busy = false; error = e.toString().replaceFirst('Exception: ', ''); });
                }
              },
              child: Text(busy ? 'Saving…' : 'Update', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    obscureText: true,
    style: TextStyle(color: kTextPrimary, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: kTextSecondary, fontSize: 13),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kAccent)),
    ),
  );

  // ── Download my data ─────────────────────────────────────────────────────────
  Future<void> _downloadData() async {
    _snack('Preparing your data…');
    try {
      final user     = await ApiService.getCachedUser();
      final sessions = await ApiService.fetchSessions(limit: 1000);
      final bca      = await ApiService.fetchBodyComposition();
      final export = {
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': user == null ? null : {'name': user.name, 'email': user.email, 'sport': user.sport},
        'sessions': sessions,
        'bodyComposition': bca,
      };
      final json = const JsonEncoder.withIndent('  ').convert(export);
      await Share.share(json, subject: 'My SolidCore data export');
    } catch (_) {
      if (mounted) _snack('Could not export your data. Please try again.');
    }
  }

  // ── Delete account ───────────────────────────────────────────────────────────
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete account?', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This is permanent and cannot be undone. All your data will be erased.',
          style: TextStyle(color: kTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dctx);
              try {
                await ApiService.deleteAccount();
                if (!mounted) return;
                // Return to the root before signing out so no settings route lingers.
                Navigator.of(context).popUntil((route) => route.isFirst);
                widget.onLoggedOut?.call(); // AuthScreen swaps to sign-in
              } catch (e) {
                if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('PRIVACY & SECURITY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: IconThemeData(color: kTextPrimary),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _SectionLabel('SECURITY'),
          const SizedBox(height: 8),
          _Group(children: [
            _RowItem(
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF38BDF8),
              label: 'Change password',
              onTap: _changePassword,
            ),
            _ToggleItem(
              icon: Icons.shield_outlined,
              iconColor: kAccent,
              label: 'Two-factor auth',
              subtitle: 'Extra sign-in protection',
              value: twoFactor,
              onChanged: (v) { setState(() => twoFactor = v); _setPref(_kTwoFactor, v); },
            ),
            _RowItem(
              icon: Icons.phone_android_rounded,
              iconColor: const Color(0xFFA78BFA),
              label: 'Manage devices',
              trailing: '2 active',
              onTap: () => _snack('Active sessions listed'),
            ),
          ]),
          const SizedBox(height: 20),

          const _SectionLabel('DATA'),
          const SizedBox(height: 8),
          _Group(children: [
            _ToggleItem(
              icon: Icons.event_note_outlined,
              iconColor: const Color(0xFF34D399),
              label: 'Daily logs',
              subtitle: 'Allow saving wellness & recovery logs',
              value: dailyLogsConsent,
              onChanged: (v) {
                setState(() => dailyLogsConsent = v);
                LocalLogStore.setDailyLogsConsent(v);
                _snack(v ? 'Daily logs enabled' : 'Daily logs turned off');
              },
            ),
            _ToggleItem(
              icon: Icons.camera_alt_outlined,
              iconColor: const Color(0xFF38BDF8),
              label: 'Camera-based features',
              subtitle: 'On-device posture, running & bowling analysis',
              value: cameraConsent,
              onChanged: (v) {
                setState(() => cameraConsent = v);
                LocalLogStore.setCameraConsent(v);
                _snack(v ? 'Camera features enabled' : 'Camera features turned off');
              },
            ),
            _ToggleItem(
              icon: Icons.analytics_outlined,
              iconColor: const Color(0xFFF59E0B),
              label: 'Analytics sharing',
              subtitle: 'Help improve SolidCore',
              value: analyticsShare,
              onChanged: (v) { setState(() => analyticsShare = v); _setPref(_kAnalytics, v); },
            ),
            _RowItem(
              icon: Icons.download_outlined,
              iconColor: kTextSecondary,
              label: 'Download my data',
              onTap: _downloadData,
            ),
          ]),
          const SizedBox(height: 20),

          const _SectionLabel('DANGER ZONE'),
          const SizedBox(height: 8),
          _DangerButton(
            icon: Icons.person_off_outlined,
            label: 'Deactivate account',
            onTap: () => _snack('Deactivation requires confirmation'),
          ),
          const SizedBox(height: 8),
          _DangerButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete account',
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: kTextSecondary),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (i) => Column(children: [
          children[i],
          if (i < children.length - 1) Divider(height: 1, indent: 54, color: kBorder),
        ])),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String?  trailing;
  final VoidCallback? onTap;
  const _RowItem({required this.icon, required this.iconColor, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary))),
            if (trailing != null) ...[
              Text(trailing!, style: TextStyle(fontSize: 13, color: kTextSecondary)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String?  subtitle;
  final bool     value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.icon, required this.iconColor, required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
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

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _DangerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}
