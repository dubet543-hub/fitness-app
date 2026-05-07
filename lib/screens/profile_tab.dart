import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'personal_info_page.dart';
import 'notifications_page.dart';
import 'privacy_security_page.dart';
import 'appearance_page.dart';
import 'units_language_page.dart';
import 'support_pages.dart';

class ProfileTab extends StatefulWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const ProfileTab({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.onLogout,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late String _name;
  late String _email;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _email = widget.email;
  }

  String get _initials {
    final parts = _name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _go(WidgetBuilder builder) {
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  void _goPersonal() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalInfoPage(name: _name, email: _email),
      ),
    );
    if (result != null) {
      setState(() {
        _name = result['name'] ?? _name;
        _email = result['email'] ?? _email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero ──────────────────────────────────────────
            Container(
              color: kSurface,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _Avatar(initials: _initials, photoUrl: widget.photoUrl),
                      Positioned(
                        bottom: 0, right: 0,
                        child: GestureDetector(
                          onTap: _goPersonal,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: kAccent,
                              shape: BoxShape.circle,
                              border: const Border.fromBorderSide(BorderSide(color: kSurface, width: 2)),
                            ),
                            child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email,
                          style: theme.textTheme.bodySmall?.copyWith(color: kTextSecondary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kCardAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kBorder),
                          ),
                          child: Text(
                            'Athlete',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats ─────────────────────────────────────────
            Container(
              color: kSurface,
              child: Row(
                children: [
                  _StatCell(value: '47', label: 'Sessions'),
                  _divider(),
                  _StatCell(value: '12', label: 'This month'),
                  _divider(),
                  _StatCell(value: '89', label: 'Avg score'),
                ],
              ),
            ),
            const Divider(height: 1, color: kBorder),

            // ── Account ───────────────────────────────────────
            _SectionLabel('Account'),
            _MenuGroup(items: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Personal info',
                onTap: _goPersonal,
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => _go((_) => const NotificationsPage()),
              ),
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'Privacy & security',
                onTap: () => _go((_) => const PrivacySecurityPage()),
              ),
            ]),

            // ── Preferences ───────────────────────────────────
            _SectionLabel('Preferences'),
            _MenuGroup(items: [
              _MenuItem(
                icon: Icons.dark_mode_outlined,
                label: 'Appearance',
                onTap: () => _go((_) => const AppearancePage()),
              ),
              _MenuItem(
                icon: Icons.straighten_rounded,
                label: 'Units & language',
                onTap: () => _go((_) => const UnitsLanguagePage()),
              ),
            ]),

            // ── Support ───────────────────────────────────────
            _SectionLabel('Support'),
            _MenuGroup(items: [
              _MenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Help center',
                onTap: () => _go((_) => const HelpCenterPage()),
              ),
              _MenuItem(
                icon: Icons.feedback_outlined,
                label: 'Send feedback',
                onTap: () => _go((_) => const FeedbackPage()),
              ),
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'About SolidCore',
                onTap: () => _go((_) => const AboutPage()),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Sign out ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: danger.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: danger.withValues(alpha: 0.25)),
                ),
                child: InkWell(
                  onTap: widget.onLogout,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: danger),
                        const SizedBox(width: 12),
                        Text(
                          'Sign out',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: danger),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: Text(
                'v1.0.0 · SolidCore Performance',
                style: TextStyle(fontSize: 11, color: kTextSecondary.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 36,
    color: kBorder,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final double radius;

  const _Avatar({required this.initials, this.photoUrl, this.radius = 36});

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();
    final hasPhoto = url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: kAccent,
      backgroundImage: hasPhoto ? NetworkImage(url) : null,
      child: !hasPhoto
          ? Text(initials, style: TextStyle(fontSize: radius * 0.6, fontWeight: FontWeight.w700, color: Colors.white))
          : null,
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: kTextSecondary,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(items.length, (i) {
            return Column(
              children: [
                items[i],
                if (i < items.length - 1) const Divider(height: 1, indent: 46, color: kBorder),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: kCardAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: kTextSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary),
              ),
            ),
            if (value != null) ...[
              Text(value!, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
              const SizedBox(width: 4),
            ],
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kTextSecondary.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}