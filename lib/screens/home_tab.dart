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
    final dateStr = _fmtDate(now);

    // Headline metrics for the three rings — computed from the same source the
    // stats/history screens use, so the numbers always agree.
    final metrics = _metrics;
    final home    = _home;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: kBg,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(
              dateStr.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
                letterSpacing: 1.4,
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: widget.onOpenProfile,
                // Without this the transparent padding around the circle would
                // not register a tap.
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  button: true,
                  label: 'Profile',
                  child: AvatarWidget(
                      name: widget.name, photoUrl: widget.photoUrl, radius: 18),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, size: 22, color: kTextSecondary),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: kBorder),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand label ─────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.only(top: 24, bottom: 2),
                  child: Text(
                    'SOLIDCORE AMS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kHeadlineFont,
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),

                // ── Three-Ring Row ───────────────────────────────────────────
                if (home == null || metrics == null)
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: kAccent),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _SpeedometerGauge(
                            value: (home.performancePct * 100).round().toString(),
                            suffix: '%',
                            label: 'PERFORMANCE',
                            progress: home.performancePct,
                            color: kSleep,
                            icon: Icons.bar_chart_rounded,
                            trend: home.performanceTrend,
                            onTap: () => Navigator.push(context, _route(const PlayerStatsScreen(initialTab: 0))),
                          ),
                        ),
                        Expanded(
                          child: _SpeedometerGauge(
                            value: (home.recoveryPct * 100).round().toString(),
                            suffix: '%',
                            label: 'RECOVERY',
                            progress: home.recoveryPct,
                            color: kAccent,
                            icon: Icons.favorite_rounded,
                            onTap: () => Navigator.push(context, _route(const PlayerStatsScreen(initialTab: 1))),
                          ),
                        ),
                        Expanded(
                          child: _SpeedometerGauge(
                            value: home.todayExertion.toStringAsFixed(1),
                            suffix: '',
                            label: 'TODAY',
                            progress: (home.todayExertion / 10).clamp(0.0, 1.0),
                            color: kExertion,
                            icon: Icons.local_fire_department_rounded,
                            maxLabel: '10',
                            onTap: () => Navigator.push(context, _route(const PlayerStatsScreen(initialTab: 2))),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!metrics.hasData)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Log training sessions to see your metrics',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: kTextSecondary),
                      ),
                    ),

                  // ── Tomorrow's Load Target (combined) ──────────────────────
                  // Only meaningful once real load exists — hidden otherwise.
                  if (metrics.hasLoadData)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: _LoadTargetCard(
                        target: metrics.loadTargets(),
                        onTap: () => FeatureGate.push(context,
                            FeatureKeys.workloadMonitoring,
                            () => const WorkloadMonitorScreen()),
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Trailing space so the last card clears the bottom nav bar.
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    const days   = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
    final dow = days[d.weekday - 1];
    return '$dow, ${months[d.month - 1]} ${d.day}';
  }

  Route _route(Widget screen) => MaterialPageRoute(builder: (_) => screen);
}

// ── Animated Gauge ────────────────────────────────────────────────────────────

class _SpeedometerGauge extends StatefulWidget {
  final String     value, suffix, label;
  final double     progress;
  final Color      color;
  final IconData   icon;
  final String     maxLabel;
  final VoidCallback onTap;
  final List<double>? trend; // optional in-gauge sparkline

  const _SpeedometerGauge({
    required this.value,
    required this.suffix,
    required this.label,
    required this.progress,
    required this.color,
    required this.icon,
    this.maxLabel = '100',
    required this.onTap,
    this.trend,
  });

  @override
  State<_SpeedometerGauge> createState() => _SpeedometerGaugeState();
}

class _SpeedometerGaugeState extends State<_SpeedometerGauge>
    with TickerProviderStateMixin {
  late final AnimationController _sweepCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _sweepAnim;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _sweepAnim = CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _sweepCtrl.forward();
    });
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: AnimatedBuilder(
              animation: Listenable.merge([_sweepAnim, _pulseAnim]),
              builder: (_, _) {
                final p = _pulseAnim.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: _SpeedometerPainter(
                        animProgress: _sweepAnim.value * widget.progress,
                        gaugeColor:   widget.color,
                        value:        widget.value,
                        suffix:       widget.suffix,
                        pulse:        p,
                        trend:        widget.trend,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.38),
                      child: _GaugeIconBadge(icon: widget.icon, color: widget.color, pulse: p),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _DotProgressBar(
              progress: widget.progress,
              color:    widget.color,
              maxLabel: widget.maxLabel,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: widget.color,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double animProgress;
  final double pulse;
  final Color  gaugeColor;
  final String value, suffix;
  final List<double>? trend;

  const _SpeedometerPainter({
    required this.animProgress,
    required this.gaugeColor,
    required this.value,
    required this.suffix,
    required this.pulse,
    this.trend,
  });

  // Arc: gap at the bottom — starts lower-left, sweeps 270° to lower-right
  static const double _startDeg = 135;
  static const double _sweepDeg = 270;

  @override
  void paint(Canvas canvas, Size size) {
    final startRad = _startDeg * pi / 180;
    final sweepRad = _sweepDeg * pi / 180;
    final cx      = size.width  / 2;
    final cy      = size.height / 2;
    final center  = Offset(cx, cy);
    final outerR  = size.width * 0.44;
    const strokeW = 7.0;
    final arcR    = outerR - strokeW / 2;
    final arcRect = Rect.fromCircle(center: center, radius: arcR);
    final faceR   = arcR - strokeW / 2 - 5;
    final faceRect = Rect.fromCircle(center: center, radius: faceR);

    // ─── 1. Ambient outer glow ────────────────────────────────────────────────
    canvas.drawCircle(center, outerR + 10,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [
            gaugeColor.withValues(alpha: 0.12 + 0.06 * pulse),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: outerR + 10)),
    );

    // ─── 2. Outer bevel ring ──────────────────────────────────────────────────
    canvas.drawCircle(center, outerR + 3,
      Paint()
        ..color       = gaugeColor.withValues(alpha: 0.08 + 0.04 * pulse)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // ─── 3. Track arc (full 270°, dim) ───────────────────────────────────────
    canvas.drawArc(arcRect, startRad, sweepRad, false,
      Paint()
        ..color       = gaugeColor.withValues(alpha: 0.14)
        ..strokeWidth = strokeW
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    // ─── 4. Progress glow + solid arc ────────────────────────────────────────
    if (animProgress > 0.001) {
      final sweepP = sweepRad * animProgress;

      canvas.drawArc(arcRect, startRad, sweepP, false,
        Paint()
          ..color       = gaugeColor.withValues(alpha: 0.28 + 0.12 * pulse)
          ..strokeWidth = 24
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawArc(arcRect, startRad, sweepP, false,
        Paint()
          ..strokeWidth = strokeW
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..shader      = SweepGradient(
            startAngle: startRad,
            endAngle:   startRad + sweepP,
            colors: [gaugeColor.withValues(alpha: 0.30), gaugeColor],
          ).createShader(arcRect),
      );

      // Glowing tip dot
      final endAngle = startRad + sweepP;
      final tipPt    = Offset(cx + arcR * cos(endAngle), cy + arcR * sin(endAngle));
      canvas.drawCircle(tipPt, 8.0 + 3.0 * pulse,
        Paint()
          ..color      = gaugeColor.withValues(alpha: 0.40 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(tipPt, 4.5, Paint()..color = gaugeColor);
      canvas.drawCircle(tipPt, 4.5,
        Paint()
          ..color       = kTextPrimary.withValues(alpha: 0.50 + 0.30 * pulse)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ─── 5. Dark face circle ─────────────────────────────────────────────────
    canvas.drawCircle(center, faceR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.0,
          colors: [const Color(0xFF14141F), const Color(0xFF060610)],
        ).createShader(faceRect),
    );
    canvas.drawCircle(center, faceR,
      Paint()
        ..color       = gaugeColor.withValues(alpha: 0.08 + 0.04 * pulse)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ─── 6. Glass gloss ──────────────────────────────────────────────────────
    final glossPath = Path()
      ..arcTo(faceRect, pi, pi, false)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(glossPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.2,
          colors: [Colors.white.withValues(alpha: 0.07), Colors.transparent],
        ).createShader(faceRect),
    );

    // ─── 6.5 Trend sparkline (in the band between icon and value) ────────────
    final t = trend;
    if (t != null && t.length >= 2) {
      final minV = t.reduce(min), maxV = t.reduce(max);
      final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
      final left  = cx - faceR * 0.52;
      final right = cx + faceR * 0.52;
      final bot   = cy - faceR * 0.04;
      final top   = cy - faceR * 0.30;
      double px(int i) => left + (right - left) * i / (t.length - 1);
      double py(double v) => bot - (bot - top) * (v - minV) / range;

      final line = Path()..moveTo(px(0), py(t[0]));
      for (int i = 1; i < t.length; i++) {
        line.lineTo(px(i), py(t[i]));
      }
      final fill = Path.from(line)
        ..lineTo(right, bot)
        ..lineTo(left, bot)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [gaugeColor.withValues(alpha: 0.22), gaugeColor.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTRB(left, top, right, bot)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = gaugeColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(
        Offset(px(t.length - 1), py(t.last)), 1.8, Paint()..color = gaugeColor);
    }

    // ─── 7. Value text (lower-center of face, below icon) ────────────────────
    final valueFontSize  = size.width * 0.22;
    final suffixFontSize = valueFontSize * 0.40;

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(children: [
        TextSpan(
          text: value,
          style: TextStyle(
            fontSize:      valueFontSize,
            fontWeight:    FontWeight.w900,
            color:         Colors.white,
            letterSpacing: -1.0,
            height:        1,
          ),
        ),
        if (suffix.isNotEmpty)
          TextSpan(
            text: suffix,
            style: TextStyle(
              fontSize:      suffixFontSize,
              fontWeight:    FontWeight.w700,
              color:         Colors.white.withValues(alpha: 0.60),
              letterSpacing: 0.5,
            ),
          ),
      ]),
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + size.height * 0.08));
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter old) =>
      old.animProgress != animProgress ||
      old.pulse        != pulse        ||
      old.gaugeColor   != gaugeColor   ||
      old.trend        != trend;
}

// ── Gauge Icon Badge ──────────────────────────────────────────────────────────

class _GaugeIconBadge extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final double   pulse;
  const _GaugeIconBadge({required this.icon, required this.color, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0C0C1C),
        border: Border.all(color: color.withValues(alpha: 0.28 + 0.14 * pulse), width: 1.5),
        boxShadow: [
          BoxShadow(
            color:        color.withValues(alpha: 0.32 + 0.16 * pulse),
            blurRadius:   14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

// ── Dot Progress Bar ──────────────────────────────────────────────────────────

class _DotProgressBar extends StatelessWidget {
  final double progress;
  final Color  color;
  final String maxLabel;
  const _DotProgressBar({required this.progress, required this.color, this.maxLabel = '100'});

  @override
  Widget build(BuildContext context) {
    const numDots    = 11;
    final filledDots = (progress * numDots).round().clamp(0, numDots);

    return Row(
      children: [
        Text('0',      style: TextStyle(fontSize: 9, color: kTextMuted)),
        const SizedBox(width: 5),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(numDots, (i) {
              final filled    = i < filledDots;
              final isCurrent = filled && i == filledDots - 1;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve:    Curves.easeOut,
                width:  isCurrent ? 14 : 5,
                height: 4,
                decoration: BoxDecoration(
                  color: filled
                      ? (isCurrent ? color : color.withValues(alpha: 0.55))
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 5),
        Text(maxLabel, style: TextStyle(fontSize: 9, color: kTextMuted)),
      ],
    );
  }
}

// ── Tomorrow's Load Target (combined card) ────────────────────────────────────

class _LoadTargetCard extends StatelessWidget {
  final CombinedLoadTarget target;
  final VoidCallback onTap;
  const _LoadTargetCard({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t    = target;
    final hero = t.total;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hero.color.withValues(alpha: 0.14), kCard],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hero.color.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: hero.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.track_changes_rounded, size: 18, color: hero.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "TOMORROW'S LOAD TARGET",
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: kTextSecondary,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kTextMuted),
            ]),
            const SizedBox(height: 14),

            // Hero range — the total target
            Text(
              '${hero.low.round()} – ${hero.high.round()}',
              style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800,
                letterSpacing: -1, color: hero.color, height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recommended total · 80–130% of chronic ${hero.chronic.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 11, color: kTextSecondary),
            ),
            const SizedBox(height: 14),

            // Breakdown — the streams that make up the total
            Row(
              children: [
                for (int i = 0; i < t.parts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _LoadTargetChip(target: t.parts[i])),
                ],
              ],
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: target.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: target.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: target.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              target.label,
              style: TextStyle(
                fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '${target.low.round()} – ${target.high.round()}',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              letterSpacing: -0.5, color: target.color,
            ),
          ),
        ],
      ),
    );
  }
}
