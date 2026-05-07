import 'package:flutter/material.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool twoFactor = false;
  bool analyticsSharing = true;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This is permanent and cannot be undone. All your data will be erased.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); _showSnack('Account deletion requested'); },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Privacy & security'), scrolledUnderElevation: 0),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _SectionLabel('Security'),
          _GroupCard(children: [
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change password', style: TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () => _showSnack('Password change flow'),
            ),
            Divider(height: 1, color: cs.outlineVariant, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.shield_outlined),
              title: const Text('Two-factor auth', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Extra sign-in protection', style: TextStyle(fontSize: 12)),
              value: twoFactor,
              onChanged: (v) => setState(() => twoFactor = v),
            ),
            Divider(height: 1, color: cs.outlineVariant, indent: 56),
            ListTile(
              leading: const Icon(Icons.phone_android_rounded),
              title: const Text('Manage devices', style: TextStyle(fontSize: 14)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('2 active', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              ]),
              onTap: () => _showSnack('Active sessions listed'),
            ),
          ]),
          _SectionLabel('Data'),
          _GroupCard(children: [
            SwitchListTile(
              secondary: const Icon(Icons.analytics_outlined),
              title: const Text('Analytics sharing', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Help improve SolidCore', style: TextStyle(fontSize: 12)),
              value: analyticsSharing,
              onChanged: (v) => setState(() => analyticsSharing = v),
            ),
            Divider(height: 1, color: cs.outlineVariant, indent: 56),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download my data', style: TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onTap: () => _showSnack('Downloading your data...'),
            ),
          ]),
          _SectionLabel('Danger zone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              _DangerButton(
                icon: Icons.person_off_outlined,
                label: 'Deactivate account',
                onTap: () => _showSnack('Deactivation requires confirmation'),
              ),
              const SizedBox(height: 8),
              _DangerButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete account',
                onTap: _confirmDelete,
              ),
            ]),
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
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.red.shade400),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
      ]),
    ),
  );
}