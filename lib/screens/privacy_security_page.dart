import 'package:flutter/material.dart';
import '../core/theme.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool twoFactor      = false;
  bool analyticsShare = true;

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'This is permanent and cannot be undone. All your data will be erased.',
          style: TextStyle(color: kTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _snack('Account deletion requested'); },
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
        title: const Text('PRIVACY & SECURITY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4)),
        iconTheme: const IconThemeData(color: kTextPrimary),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: kBorder)),
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
              onTap: () => _snack('Password change flow'),
            ),
            _ToggleItem(
              icon: Icons.shield_outlined,
              iconColor: kAccent,
              label: 'Two-factor auth',
              subtitle: 'Extra sign-in protection',
              value: twoFactor,
              onChanged: (v) => setState(() => twoFactor = v),
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
              icon: Icons.analytics_outlined,
              iconColor: const Color(0xFFF59E0B),
              label: 'Analytics sharing',
              subtitle: 'Help improve SolidCore',
              value: analyticsShare,
              onChanged: (v) => setState(() => analyticsShare = v),
            ),
            _RowItem(
              icon: Icons.download_outlined,
              iconColor: kTextSecondary,
              label: 'Download my data',
              onTap: () => _snack('Downloading your data…'),
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
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: kTextSecondary),
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
          if (i < children.length - 1) const Divider(height: 1, indent: 54, color: kBorder),
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
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary))),
            if (trailing != null) ...[
              Text(trailing!, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
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
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
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
