import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import '../posture_screen.dart';
import '../training_load_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import 'workload_monitor_screen.dart';
import 'wellness_log_screen.dart';
import 'sleep_monitor_screen.dart';

class HomeTab extends StatelessWidget {
  final String  name;
  final String  email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const HomeTab({
    super.key,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onLogout,
  });

  String get _firstName => name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = _fmtDate(now);

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
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chevron_left_rounded, color: kTextSecondary, size: 22),
                const SizedBox(width: 6),
                Text(
                  dateStr.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: kTextSecondary, size: 22),
              ],
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: AvatarWidget(name: name, photoUrl: photoUrl, radius: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 22, color: kTextSecondary),
                onPressed: () {},
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: kBorder),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand label ─────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(top: 24, bottom: 2),
                  child: Text(
                    'SOLIDCORE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),

                // ── Three-Ring Row ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _SpeedometerGauge(
                          value: '74',
                          suffix: '%',
                          label: 'SLEEP',
                          progress: 0.74,
                          color: kSleep,
                          onTap: () => Navigator.push(context, _route(const SleepMonitorScreen())),
                        ),
                      ),
                      Expanded(
                        child: _SpeedometerGauge(
                          value: '78',
                          suffix: '%',
                          label: 'RECOVERY',
                          progress: 0.78,
                          color: kAccent,
                          onTap: () {},
                        ),
                      ),
                      Expanded(
                        child: _SpeedometerGauge(
                          value: '8.2',
                          suffix: '',
                          label: 'STRAIN',
                          progress: 0.55,
                          color: kStrain,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Monitor Cards ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MonitorCard(
                          title: 'HEALTH MONITOR',
                          statusColor: kAccent,
                          statusLabel: 'WITHIN RANGE',
                          detail: '5/5 Metrics',
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MonitorCard(
                          title: 'STRESS MONITOR',
                          statusColor: Colors.orangeAccent,
                          statusLabel: 'MEDIUM',
                          detail: 'Updated now',
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),

                // ── My Day ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                  child: Row(
                    children: [
                      const Text(
                        'MY DAY',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorder),
                          ),
                          child: const Icon(Icons.add_rounded, size: 20, color: kTextPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Day In Review ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _DayReviewCard(firstName: _firstName),
                ),

                // ── Tonight's Sleep ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _SleepCard(),
                ),

                // ── Features ─────────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'FEATURES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Feature Grid ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Posture',
                  subtitle: 'Body alignment',
                  accentColor: const Color(0xFF38BDF8),
                  onTap: () => Navigator.push(context, _route(const PostureGuideScreen())),
                ),
                _FeatureCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Training Load',
                  subtitle: 'Workload monitor',
                  accentColor: kAccent,
                  onTap: () => Navigator.push(context, _route(const TrainingLoadScreen())),
                ),
                _FeatureCard(
                  icon: Icons.directions_run_rounded,
                  title: 'Running',
                  subtitle: 'Form analysis',
                  accentColor: const Color(0xFFFF6B35),
                  onTap: () => Navigator.push(context, _route(const RunningAnalysisScreen())),
                ),
                _FeatureCard(
                  icon: Icons.sports_cricket_rounded,
                  title: 'Bowling',
                  subtitle: 'Technique',
                  accentColor: kSleep,
                  onTap: () => Navigator.push(context, _route(const BowlingAnalysisScreen())),
                ),
                _FeatureCard(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Workload',
                  subtitle: 'Load monitoring',
                  accentColor: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, _route(const WorkloadMonitorScreen())),
                ),
                _FeatureCard(
                  icon: Icons.health_and_safety_rounded,
                  title: 'Wellness',
                  subtitle: 'Sleep & Mood',
                  accentColor: const Color(0xFF818CF8),
                  onTap: () => Navigator.push(context, _route(const WellnessLogScreen())),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
            ),
          ),

          // ── Recent Sessions ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 6),
              child: const Text(
                'RECENT SESSIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    children: [
                      _RecentSessionRow(
                        icon: Icons.directions_run_rounded,
                        color: const Color(0xFFFF6B35),
                        title: 'Running Analysis',
                        time: '2h ago',
                        score: 87,
                      ),
                      Divider(height: 1, indent: 56, color: kBorder),
                      _RecentSessionRow(
                        icon: Icons.accessibility_new_rounded,
                        color: const Color(0xFF38BDF8),
                        title: 'Posture Check',
                        time: 'Yesterday',
                        score: 92,
                      ),
                      Divider(height: 1, indent: 56, color: kBorder),
                      _RecentSessionRow(
                        icon: Icons.bar_chart_rounded,
                        color: kAccent,
                        title: 'Training Load',
                        time: '2d ago',
                        score: 78,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
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

// ── Premium Animated Speedometer Gauge ───────────────────────────────────────

class _SpeedometerGauge extends StatefulWidget {
  final String value, suffix, label;
  final double progress;
  final Color  color;
  final VoidCallback onTap;

  const _SpeedometerGauge({
    required this.value,
    required this.suffix,
    required this.label,
    required this.progress,
    required this.color,
    required this.onTap,
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
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _sweepAnim = CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
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
              builder: (_, __) {
                final p = _pulseAnim.value;
                return CustomPaint(
                  painter: _SpeedometerPainter(
                    animProgress: _sweepAnim.value * widget.progress,
                    gaugeColor:   widget.color,
                    value:        widget.value,
                    suffix:       widget.suffix,
                    pulse:        p,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward_ios_rounded, size: 9, color: widget.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double animProgress; // 0.0 → target (driven by animation)
  final double pulse;        // 0.0 → 1.0 repeating (glow throb)
  final Color  gaugeColor;
  final String value, suffix;

  const _SpeedometerPainter({
    required this.animProgress,
    required this.gaugeColor,
    required this.value,
    required this.suffix,
    required this.pulse,
  });

  static const double _startDeg  = 150;
  static const double _sweepDeg  = 240;
  static const int    _numTicks  = 24;
  static const Color  _needleRed = Color(0xFFFF2E2E);

  @override
  void paint(Canvas canvas, Size size) {
    final startRad = _startDeg * pi / 180;
    final sweepRad = _sweepDeg * pi / 180;
    final cx = size.width / 2;
    final cy = size.height * 0.52;
    final center  = Offset(cx, cy);
    final outerR  = size.width * 0.41;
    const strokeW = 5.5;
    final arcR    = outerR - strokeW / 2;
    final arcRect = Rect.fromCircle(center: center, radius: arcR);
    final faceRect = Rect.fromCircle(center: center, radius: outerR + 6);

    // ─── 1. Background radial bloom ────────────────────────────────────────
    canvas.drawCircle(center, outerR + 6,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.0,
          colors: [
            gaugeColor.withValues(alpha: 0.10 + 0.04 * pulse),
            Colors.transparent,
          ],
        ).createShader(faceRect),
    );

    // ─── 2. Outer 3-D bevel ring ────────────────────────────────────────────
    canvas.drawCircle(center, outerR + 4.5,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.45),
            Colors.black.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR + 4.5))
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // ─── 3. Concentric depth rings ─────────────────────────────────────────
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, outerR - 5.5 * i,
        Paint()
          ..color       = Colors.white.withValues(alpha: 0.016 * (4 - i))
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }

    // ─── 4. Outer colored tick ring ─────────────────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerR + 1.5),
      startRad, sweepRad, false,
      Paint()
        ..color       = gaugeColor.withValues(alpha: 0.28)
        ..strokeWidth = 1.3
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    // ─── 5. Track arc (dim gauge color) ─────────────────────────────────────
    canvas.drawArc(arcRect, startRad, sweepRad, false,
      Paint()
        ..color       = gaugeColor.withValues(alpha: 0.12)
        ..strokeWidth = strokeW
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    // ─── 6. Progress arc (dark→bright same hue) ──────────────────────────────
    if (animProgress > 0.001) {
      final sweepP    = sweepRad * animProgress;
      // Glow intensity scales with how full the gauge is
      final glowAlpha = 0.15 + 0.25 * animProgress;

      // Wide outer glow
      canvas.drawArc(arcRect, startRad, sweepP, false,
        Paint()
          ..color       = gaugeColor.withValues(alpha: glowAlpha + 0.10 * pulse)
          ..strokeWidth = 22
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Mid glow
      canvas.drawArc(arcRect, startRad, sweepP, false,
        Paint()
          ..color       = gaugeColor.withValues(alpha: (glowAlpha + 0.30) + 0.15 * pulse)
          ..strokeWidth = 9
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Solid arc: near-black at start → full vivid color at tip
      canvas.drawArc(arcRect, startRad, sweepP, false,
        Paint()
          ..strokeWidth = strokeW
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..shader      = SweepGradient(
            startAngle: startRad,
            endAngle:   startRad + sweepP,
            colors: [
              gaugeColor.withValues(alpha: 0.18), // dark/dim at 0%
              gaugeColor,                          // full vivid at tip
            ],
          ).createShader(arcRect),
      );

      // Pulsing hot dot at arc tip
      final endAngle = startRad + sweepP;
      final arcTip   = Offset(cx + arcR * cos(endAngle), cy + arcR * sin(endAngle));
      canvas.drawCircle(arcTip, 5.5 + 3.5 * pulse,
        Paint()
          ..color      = gaugeColor.withValues(alpha: 0.55 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(arcTip, 2.2,
        Paint()..color = Colors.white.withValues(alpha: 0.70 + 0.30 * pulse),
      );
    }

    // ─── 7. Tick marks (lit ticks brighten from start→tip) ───────────────────
    final tickR    = arcR - strokeW / 2 - 2.5;
    final safeAnim = animProgress.clamp(0.001, 1.0);
    for (int i = 0; i <= _numTicks; i++) {
      final frac  = i / _numTicks;
      final angle = startRad + sweepRad * frac;
      final isLit = frac <= animProgress;
      final isMaj = i % 6 == 0;
      final isMid = i % 3 == 0 && !isMaj;
      final len   = isMaj ? 11.0 : (isMid ? 6.5 : 3.5);
      final thick = isMaj ? 2.0 : (isMid ? 1.1 : 0.7);
      // Lit ticks: dim near arc-start, bright near needle tip
      final litBrightness = isLit ? (frac / safeAnim).clamp(0.0, 1.0) : 0.0;
      final col   = isLit ? gaugeColor : Colors.white;
      final alpha = isLit
          ? (isMaj ? 0.30 + 0.70 * litBrightness
                   : (isMid ? 0.18 + 0.52 * litBrightness
                            : 0.08 + 0.27 * litBrightness))
          : (isMaj ? 0.38 : (isMid ? 0.18 : 0.08));
      final c_    = cos(angle);
      final s_    = sin(angle);
      canvas.drawLine(
        Offset(cx + tickR * c_,          cy + tickR * s_),
        Offset(cx + (tickR - len) * c_,  cy + (tickR - len) * s_),
        Paint()
          ..color       = col.withValues(alpha: alpha)
          ..strokeWidth = thick
          ..strokeCap   = StrokeCap.round,
      );
    }

    // ─── 8. Needle glow trail ────────────────────────────────────────────────
    final needleAngle = startRad + sweepRad * animProgress;
    final needleLen   = arcR - strokeW - 10;
    final tipPt  = Offset(cx + needleLen * cos(needleAngle),
                          cy + needleLen * sin(needleAngle));
    final basePt = Offset(cx - 8.0 * cos(needleAngle),
                          cy - 8.0 * sin(needleAngle));

    canvas.drawLine(basePt, tipPt,
      Paint()
        ..color       = _needleRed.withValues(alpha: 0.35 + 0.28 * pulse)
        ..strokeWidth = 12
        ..strokeCap   = StrokeCap.round
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ─── 9. Tapered needle (triangle + specular) ─────────────────────────────
    final perp  = needleAngle + pi / 2;
    const baseHW = 3.2;
    final bL    = Offset(basePt.dx + baseHW * cos(perp), basePt.dy + baseHW * sin(perp));
    final bR    = Offset(basePt.dx - baseHW * cos(perp), basePt.dy - baseHW * sin(perp));
    final nPath = Path()
      ..moveTo(tipPt.dx, tipPt.dy)
      ..lineTo(bL.dx, bL.dy)
      ..lineTo(bR.dx, bR.dy)
      ..close();

    canvas.drawPath(nPath,               // drop shadow
      Paint()
        ..color      = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(nPath,               // gradient fill
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: const [Color(0xFFFF6666), Color(0xFFAA0808)],
        ).createShader(Rect.fromPoints(basePt, tipPt)),
    );
    canvas.drawLine(                     // specular edge
      Offset(basePt.dx + 0.6 * cos(perp), basePt.dy + 0.6 * sin(perp)),
      Offset(tipPt.dx  + 0.3 * cos(perp), tipPt.dy  + 0.3 * sin(perp)),
      Paint()
        ..color       = Colors.white.withValues(alpha: 0.30)
        ..strokeWidth = 0.8
        ..strokeCap   = StrokeCap.round,
    );

    // ─── 10. Metallic hub (7 layers) ────────────────────────────────────────
    canvas.drawCircle(center, 13,
      Paint()
        ..color      = Colors.black.withValues(alpha: 0.70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(center, 11,        // sweep metallic bevel
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.38),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 11))
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    canvas.drawCircle(center, 9.5,       // dark face
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 1.0,
          colors: [const Color(0xFF363650), const Color(0xFF101022)],
        ).createShader(Rect.fromCircle(center: center, radius: 9.5)),
    );
    canvas.drawCircle(center, 9.5,       // colored ring pulse
      Paint()
        ..color       = gaugeColor.withValues(alpha: 0.50 + 0.25 * pulse)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawCircle(center, 6.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.3),
          radius: 1.0,
          colors: [const Color(0xFF2A2A40), const Color(0xFF0A0A18)],
        ).createShader(Rect.fromCircle(center: center, radius: 6.5)),
    );
    canvas.drawCircle(center, 4.8, Paint()..color = _needleRed);
    canvas.drawCircle(center, 4.8,       // red pulse glow
      Paint()
        ..color      = _needleRed.withValues(alpha: 0.60 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(Offset(cx - 2.5, cy - 2.5), 1.9,  // specular
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );

    // ─── 11. Glass gloss (upper half filled arc) ─────────────────────────────
    final glossPath = Path()
      ..arcTo(faceRect, pi, pi, false)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(glossPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.3,
          colors: [
            Colors.white.withValues(alpha: 0.09),
            Colors.transparent,
          ],
        ).createShader(faceRect),
    );

    // ─── 12. Value pill + text ───────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 17), width: 56, height: 24),
        const Radius.circular(7),
      ),
      Paint()
        ..color      = gaugeColor.withValues(alpha: 0.15 + 0.06 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(children: [
        TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        if (suffix.isNotEmpty)
          TextSpan(
            text: suffix,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
      ]),
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 14));
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter old) =>
      old.animProgress != animProgress ||
      old.pulse        != pulse        ||
      old.gaugeColor   != gaugeColor;
}

// ── Monitor Card ──────────────────────────────────────────────────────────────

class _MonitorCard extends StatelessWidget {
  final String title, statusLabel, detail;
  final Color statusColor;
  final VoidCallback onTap;

  const _MonitorCard({
    required this.title,
    required this.statusColor,
    required this.statusLabel,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kTextMuted),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(fontSize: 10, color: kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Day In Review Card ────────────────────────────────────────────────────────

class _DayReviewCard extends StatelessWidget {
  final String firstName;
  const _DayReviewCard({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kAccent.withValues(alpha: 0.18), kStrain.withValues(alpha: 0.12)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.nights_stay_rounded, color: kAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your Day In Review',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Tonight's Sleep Card ──────────────────────────────────────────────────────

class _SleepCard extends StatelessWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "TONIGHT'S SLEEP",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 0.8),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kTextMuted),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Icon(Icons.bedtime_rounded, size: 16, color: kTextSecondary),
                        SizedBox(width: 6),
                        Text(
                          '9:21',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'RECOMMENDED\nBEDTIME',
                      style: TextStyle(fontSize: 9, color: kTextSecondary, letterSpacing: 0.3, height: 1.4),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: kBorder),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Icon(Icons.alarm_rounded, size: 16, color: kAccent),
                          SizedBox(width: 6),
                          Text(
                            '8:30',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: const [
                          Icon(Icons.circle, size: 7, color: kAccent),
                          SizedBox(width: 4),
                          Text(
                            'ALARM ON',
                            style: TextStyle(fontSize: 9, color: kAccent, letterSpacing: 0.3, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Feature Card ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData     icon;
  final String       title, subtitle;
  final Color        accentColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 19),
            ),
            const Spacer(),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: kTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: kTextSecondary, fontSize: 10.5)),
            const SizedBox(height: 10),
            Container(
              width: 22,
              height: 2.5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Session Row ────────────────────────────────────────────────────────

class _RecentSessionRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title, time;
  final int      score;

  const _RecentSessionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}
