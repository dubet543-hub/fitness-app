import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/dashboard_metrics.dart';
import 'notifications_page.dart';
import 'player_stats_screen.dart';
// Navigation target only — LoadTarget/CombinedLoadTarget come from the
// dashboard_metrics service.
import 'workload_monitor_screen.dart' show WorkloadMonitorScreen;
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

class HomeTab extends StatefulWidget {
  final String  name;
  final String  email;
  final String? photoUrl;
  final VoidCallback onLogout;

  /// Switches the shell to the Profile tab. Required rather than optional so a
  /// caller cannot silently leave the avatar inert.
  final VoidCallback onOpenProfile;

  const HomeTab({
    super.key,
    required this.name,
    required this.email,
    required this.onOpenProfile,
    required this.photoUrl,
    required this.onLogout,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Null while AthleteMetricsService.load() is in flight; the rings row shows a
  // progress indicator until both are populated together in one setState.
  AthleteMetrics? _metrics;
  HomeMetrics?    _home;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    // The Home tab is kept alive in an IndexedStack rather than rebuilt on
    // tab switch, so without this it would only pick up a just-logged
    // session on the next app relaunch — this makes the ring update the
    // moment a training/wellness log screen saves.
    AthleteMetricsService.revision.addListener(_loadMetrics);
  }

  @override
  void dispose() {
    AthleteMetricsService.revision.removeListener(_loadMetrics);
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    AthleteMetrics m;
    try {
      // The signed-in athlete's real sessions (JWT-authenticated, cached).
      m = await AthleteMetricsService.load();
    } catch (_) {
      // Network/auth failure — render the empty-state layout rather than spin
      // forever; a tab revisit or pull elsewhere will retry via the cache.
      m = AthleteMetrics.empty;
    }
    if (!mounted) return;
    setState(() {
      _metrics = m;
      _home    = m.homeMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final metrics = _metrics;
    final home    = _home;
    final first   = widget.name.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: kAccent,
          backgroundColor: kCard,
          onRefresh: _loadMetrics,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 12, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fmtDate(now), style: const TextStyle(fontSize: 14, color: kTextSecondary, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Semantics(
                              header: true,
                              child: Text(
                                first.isEmpty ? 'Today' : '${_greeting(now)}, $first',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.6, height: 1.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 24, color: kTextPrimary),
                        tooltip: 'Notifications',
                        onPressed: () => Navigator.push(context, _route(const NotificationsPage())),
                      ),
                      Semantics(
                        button: true,
                        label: 'Profile',
                        child: InkResponse(
                          onTap: widget.onOpenProfile,
                          radius: 26,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: AvatarWidget(name: widget.name, photoUrl: widget.photoUrl, radius: 17),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
                  child: home == null || metrics == null
                      ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Today's three numbers ─────────────────────────
                            _Panel(
                              padding: const EdgeInsets.fromLTRB(8, 20, 8, 18),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _MetricRing(
                                      value: (home.performancePct * 100).round().toString(),
                                      unit: '%',
                                      label: 'Performance',
                                      progress: home.performancePct,
                                      color: kSleep,
                                      onTap: () => Navigator.push(context, _route(const PlayerStatsScreen(initialTab: 0))),
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetricRing(
                                      value: (home.recoveryPct * 100).round().toString(),
                                      unit: '%',
                                      label: 'Recovery',
                                      progress: home.recoveryPct,
                                      color: kAccent,
                                      onTap: () => Navigator.push(context, _route(const PlayerStatsScreen(initialTab: 1))),
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetricRing(
                                      value: home.todayExertion.toStringAsFixed(1),
                                      unit: '/10',
                                      label: 'Exertion',
                                      progress: (home.todayExertion / 10).clamp(0.0, 1.0),
                                      color: kExertion,
                                      onTap: () => Navigator.push(context, _route(const PlayerStatsScreen(initialTab: 2))),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (!metrics.hasData) ...[
                              const SizedBox(height: 14),
                              const Text(
                                'Log a training session to see your numbers here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: kTextSecondary),
                              ),
                            ],

                            // ── Tomorrow's load target ────────────────────────
                            if (metrics.hasLoadData) ...[
                              const SizedBox(height: 12),
                              _LoadTargetCard(
                                target: metrics.loadTargets(),
                                onTap: () => FeatureGate.push(context,
                                    FeatureKeys.workloadMonitoring,
                                    () => const WorkloadMonitorScreen()),
                              ),
                            ],
                          ],
                        ),
                ),
              ),

              // Trailing space so the last card clears the bottom nav bar.
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(DateTime d) => d.hour < 12 ? 'Good morning' : d.hour < 17 ? 'Good afternoon' : 'Good evening';

  String _fmtDate(DateTime d) {
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    const days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  Route _route(Widget screen) => MaterialPageRoute(builder: (_) => screen);
}

// ── Panel ─────────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorder, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () { hapticSelect(); onTap!(); },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ── Metric ring ───────────────────────────────────────────────────────────────
// Thin ring with rounded ends, value in the middle, label underneath. The ring
// sweeps in once on load; no glow, pulse or decoration.

class _MetricRing extends StatefulWidget {
  final String value, unit, label;
  final double progress;
  final Color color;
  final VoidCallback onTap;

  const _MetricRing({
    required this.value,
    required this.unit,
    required this.label,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MetricRing> createState() => _MetricRingState();
}

class _MetricRingState extends State<_MetricRing> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final Animation<double> _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label} ${widget.value}${widget.unit}. Opens details.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () { hapticSelect(); widget.onTap(); },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, child) => CustomPaint(
                    painter: _RingPainter(progress: widget.progress.clamp(0.0, 1.0) * _anim.value, color: widget.color),
                    child: child,
                  ),
                  child: Center(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: widget.value,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.8, height: 1),
                        ),
                        TextSpan(
                          text: widget.unit,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final r = size.shortestSide / 2 - stroke / 2 - 4;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kBorderBright);
    if (progress > 0) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

// ── Tomorrow's Load Target ────────────────────────────────────────────────────

class _LoadTargetCard extends StatelessWidget {
  final CombinedLoadTarget target;
  final VoidCallback onTap;
  const _LoadTargetCard({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t    = target;
    final hero = t.total;
    return Semantics(
      button: true,
      label: "Tomorrow's load target ${hero.low.round()} to ${hero.high.round()}. Opens workload monitor.",
      child: _Panel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Expanded(
                child: Text("Tomorrow's load target",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextSecondary)),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
            ]),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(
                text: '${hero.low.round()}–${hero.high.round()}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, color: kTextPrimary, height: 1.05),
              ),
              const TextSpan(text: '  AU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextSecondary)),
            ])),
            const SizedBox(height: 4),
            Text(
              '80–130% of your chronic load (${hero.chronic.toStringAsFixed(0)})',
              style: const TextStyle(fontSize: 13, color: kTextSecondary),
            ),
            if (t.parts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 0.6),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (int i = 0; i < t.parts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: _LoadTargetChip(target: t.parts[i])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadTargetChip extends StatelessWidget {
  final LoadTarget target;
  const _LoadTargetChip({required this.target});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: target.color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(target.label, style: const TextStyle(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 4),
        Text(
          '${target.low.round()}–${target.high.round()}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: kTextPrimary),
        ),
      ],
    );
  }
}
