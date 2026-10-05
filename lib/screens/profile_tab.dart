import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/dashboard_metrics.dart';
import '../widgets/common_widgets.dart' show SectionHeader;
import 'personal_info_page.dart';
import 'notifications_page.dart';
import 'privacy_security_page.dart';
import 'units_language_page.dart';
import 'support_pages.dart';
import 'legal_pages.dart';
import 'subscription_page.dart';

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

  // Null until the athlete's real metrics load; the stat row shows em-dashes
  // in the meantime rather than any placeholder number.
  AthleteMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _name  = widget.name;
    _email = widget.email;
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    AthleteMetrics m;
    try {
      m = await AthleteMetricsService.load();
    } catch (_) {
      m = AthleteMetrics.empty;
    }
    if (mounted) setState(() => _metrics = m);
  }

  /// Training days logged in the last 90 days (the metrics window).
  String get _sessionsStat {
    final m = _metrics;
    if (m == null) return '—';
    return m.total.where((p) => p.load > 0).length.toString();
  }

  /// Training days logged this calendar month.
  String get _thisMonthStat {
    final m = _metrics;
    if (m == null) return '—';
    final now = DateTime.now();
    return m.total
        .where((p) => p.load > 0 && p.date.year == now.year && p.date.month == now.month)
        .length
        .toString();
  }

  /// Average readiness across logged check-ins, as a 0–100 score.
  String get _avgScoreStat {
    final m = _metrics;
    if (m == null || m.recovery.isEmpty) return '—';
    final avg = m.recovery.map((r) => r.readinessPct).reduce((a, b) => a + b) /
        m.recovery.length;
    return (avg * 100).round().toString();
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
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 32),
          children: [
            // ── Title ───────────────────────────────────────────────────────
            Semantics(
              header: true,
              child: const Text(
                'Profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.6, height: 1.15),
              ),
            ),
            const SizedBox(height: 20),

            // ── Identity ────────────────────────────────────────────────────
            Row(
              children: [
                ExcludeSemantics(
                  child: InkResponse(
                    onTap: () { hapticSelect(); _goPersonal(); },
                    radius: 36,
                    child: _Avatar(initials: _initials, photoUrl: widget.photoUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: kTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder, width: 0.6),
                        ),
                        child: const Text(
                          'Athlete',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () { hapticSelect(); _goPersonal(); },
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stats ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: kBorder, width: 0.6),
              ),
              child: Row(
                children: [
                  _StatCell(value: _sessionsStat,  label: 'Sessions'),
                  const _StatDivider(),
                  _StatCell(value: _thisMonthStat, label: 'This month'),
                  const _StatDivider(),
                  _StatCell(value: _avgScoreStat,  label: 'Avg score'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Account ─────────────────────────────────────────────────────
            const _GroupLabel('Account'),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.person_outline_rounded,     label: 'Personal info',      onTap: _goPersonal),
              _MenuItem(icon: Icons.workspace_premium_outlined, label: 'Subscription',       onTap: () => _go((_) => const SubscriptionPage())),
              _MenuItem(icon: Icons.notifications_none_rounded, label: 'Notifications',      onTap: () => _go((_) => const NotificationsPage())),
              _MenuItem(icon: Icons.lock_outline_rounded,       label: 'Privacy & security', onTap: () => _go((_) => PrivacySecurityPage(onLoggedOut: widget.onLogout))),
            ]),

            const SizedBox(height: 24),

            // ── Preferences ─────────────────────────────────────────────────
            const _GroupLabel('Preferences'),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.language_rounded, label: 'Language', onTap: () => _go((_) => const UnitsLanguagePage())),
            ]),

            const SizedBox(height: 24),

            // ── Support ─────────────────────────────────────────────────────
            const _GroupLabel('Support'),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.help_outline_rounded, label: 'Help center',     onTap: () => _go((_) => const HelpCenterPage())),
              _MenuItem(icon: Icons.chat_bubble_outline_rounded, label: 'Send feedback', onTap: () => _go((_) => const FeedbackPage())),
              _MenuItem(icon: Icons.info_outline_rounded, label: 'About SolidCore', onTap: () => _go((_) => const AboutPage())),
            ]),

            const SizedBox(height: 24),

            // ── Legal ───────────────────────────────────────────────────────
            const _GroupLabel('Legal'),
            _MenuGroup(items: [
              _MenuItem(icon: Icons.description_outlined, label: 'Terms & conditions', onTap: () => _go((_) => const TermsPage())),
              _MenuItem(icon: Icons.privacy_tip_outlined, label: 'Privacy policy',     onTap: () => _go((_) => const PrivacyPolicyPage())),
            ]),

            const SizedBox(height: 32),

            // ── Sign out ────────────────────────────────────────────────────
            _MenuGroup(items: [
              _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                destructive: true,
                onTap: widget.onLogout,
              ),
            ]),

            const SizedBox(height: 20),
            const Center(
              child: Text(
                'v1.0.0 · SolidCore AMS',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ),
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
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kBorderBright, width: 1),
      ),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: kCard,
        backgroundImage: hasPhoto ? NetworkImage(url) : null,
        child: !hasPhoto
            ? Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.4))
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
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.8, height: 1.1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 0.6, height: 36, color: kBorder);
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: SectionHeader(text),
  );
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

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
            if (i > 0) const Divider(height: 0.6, thickness: 0.6, indent: 52, color: kBorder),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final bool       destructive;
  final VoidCallback? onTap;

  const _MenuItem({required this.icon, required this.label, this.destructive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? kDanger : kTextPrimary;
    return InkWell(
      onTap: onTap == null ? null : () { hapticSelect(); onTap!(); },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: destructive ? kDanger : kTextSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg)),
              ),
              if (!destructive)
                const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}
