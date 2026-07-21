import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'personal_info_page.dart';
import 'notifications_page.dart';
import 'privacy_security_page.dart';
import 'appearance_page.dart';
import 'units_language_page.dart';
import 'support_pages.dart';
import 'legal_pages.dart';

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
    _name  = widget.name;
    _email = widget.email;
  }

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _go(WidgetBuilder builder) =>
      Navigator.push(context, MaterialPageRoute(builder: builder));

  void _goPersonal() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => PersonalInfoPage(name: _name, email: _email)),
    );
    if (result != null) {
      setState(() {
        _name  = result['name']  ?? _name;
        _email = result['email'] ?? _email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text(
          'PROFILE',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: kAccent,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(BorderSide(color: kBg, width: 2)),
                            ),
                            child: Icon(Icons.edit_rounded, size: 12, color: kOnAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 3),
                        Text(_email, style: TextStyle(fontSize: 13, color: kTextSecondary)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            'Athlete',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kAccent, letterSpacing: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats ─────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  _StatCell(value: '47',  label: 'Sessions'),
                  Container(width: 1, height: 36, color: kBorder),
                  _StatCell(value: '12',  label: 'This month'),
                  Container(width: 1, height: 36, color: kBorder),
                  _StatCell(value: '89',  label: 'Avg score'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Account ───────────────────────────────────────────
            _SectionLabel('ACCOUNT'),
            const SizedBox(height: 8),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.person_outline_rounded, iconColor: kSky, label: 'Personal info',      onTap: _goPersonal),
              _MenuItem(icon: Icons.notifications_outlined,  iconColor: kWarn, label: 'Notifications',      onTap: () => _go((_) => const NotificationsPage())),
              _MenuItem(icon: Icons.lock_outline_rounded,    iconColor: kViolet, label: 'Privacy & security', onTap: () => _go((_) => PrivacySecurityPage(onLoggedOut: widget.onLogout))),
            ]),

            const SizedBox(height: 20),

            // ── Preferences ───────────────────────────────────────
            _SectionLabel('PREFERENCES'),
            const SizedBox(height: 8),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.dark_mode_outlined,  iconColor: kTextSecondary, label: 'Appearance',      onTap: () => _go((_) => AppearancePage())),
              _MenuItem(icon: Icons.straighten_rounded,  iconColor: kTextSecondary, label: 'Units & language', onTap: () => _go((_) => UnitsLanguagePage())),
            ]),

            const SizedBox(height: 20),

            // ── Support ───────────────────────────────────────────
            _SectionLabel('SUPPORT'),
            const SizedBox(height: 8),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.help_outline_rounded,  iconColor: kTextSecondary, label: 'Help center',      onTap: () => _go((_) => HelpCenterPage())),
              _MenuItem(icon: Icons.feedback_outlined,     iconColor: kTextSecondary, label: 'Send feedback',    onTap: () => _go((_) => FeedbackPage())),
              _MenuItem(icon: Icons.info_outline_rounded,  iconColor: kTextSecondary, label: 'About SolidCore',  onTap: () => _go((_) => AboutPage())),
            ]),

            const SizedBox(height: 20),

            // ── Legal ─────────────────────────────────────────────
            _SectionLabel('LEGAL'),
            const SizedBox(height: 8),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.description_outlined,   iconColor: kTextSecondary, label: 'Terms & Conditions', onTap: () => _go((_) => const TermsPage())),
              _MenuItem(icon: Icons.privacy_tip_outlined,   iconColor: kTextSecondary, label: 'Privacy Policy',     onTap: () => _go((_) => const PrivacyPolicyPage())),
            ]),

            const SizedBox(height: 28),

            // ── Sign out ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: widget.onLogout,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: kDanger),
                      const SizedBox(width: 12),
                      Text(
                        'Sign out',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kDanger),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'v1.0.0 · SolidCore Performance',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String  initials;
  final String? photoUrl;

  const _Avatar({required this.initials, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final url      = (photoUrl ?? '').trim();
    final hasPhoto = url.isNotEmpty;
    return Container(
      width: 76, height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kAccent, width: 2),
      ),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: kCard,
        backgroundImage: hasPhoto ? NetworkImage(url) : null,
        child: !hasPhoto
            ? Text(initials, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary))
            : null,
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: kTextSecondary)),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextSecondary),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(items.length, (i) {
            return Column(
              children: [
                items[i],
                if (i < items.length - 1) Divider(height: 1, indent: 54, color: kBorder),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData   icon;
  final Color      iconColor;
  final String     label;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.iconColor, required this.label, this.onTap});

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
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}
