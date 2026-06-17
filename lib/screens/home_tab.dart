import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import '../training_load_screen.dart';
import '../posture_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import 'workload_monitor_screen.dart';
import 'wellness_log_screen.dart';
import 'body_composition_screen.dart';

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
                          label: 'PERFORMANCE',
                          progress: 0.74,
                          color: kSleep,
                          icon: Icons.bar_chart_rounded,
                          onTap: () => Navigator.push(context, _route(const TrainingLoadScreen())),
                        ),
                      ),
                      Expanded(
                        child: _SpeedometerGauge(
                          value: '78',
                          suffix: '%',
                          label: 'RECOVERY',
                          progress: 0.78,
                          color: kAccent,
                          icon: Icons.favorite_rounded,
                          onTap: () => Navigator.push(context, _route(const WellnessLogScreen())),
                        ),
                      ),
                      Expanded(
                        child: _SpeedometerGauge(
                          value: '8.2',
                          suffix: '',
                          label: 'TODAY',
                          progress: 0.41,
                          color: kStrain,
                          icon: Icons.local_fire_department_rounded,
                          maxLabel: '20',
                          onTap: () => Navigator.push(context, _route(const WorkloadMonitorScreen(initialRange: 'today'))),
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

                // ── Analysis Buttons ─────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 16, 12),
                  child: Text(
                    'ANALYSIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: [
                        _AnalysisButton(
                          icon: Icons.monitor_heart_rounded,
                          color: const Color(0xFFF59E0B),
                          title: 'Workload Monitoring',
                          subtitle: 'Performance · Recovery · Load',
                          onTap: () => Navigator.push(context, _route(const WorkloadMonitorScreen())),
                        ),
                        const Divider(height: 1, indent: 60, color: kBorder),
                        _AnalysisButton(
                          icon: Icons.person_outline_rounded,
                          color: const Color(0xFFF97316),
                          title: 'Body Composition Analysis',
                          subtitle: 'Fat, muscle & structural metrics',
                          onTap: () => Navigator.push(context, _route(const BodyCompositionScreen())),
                        ),
                        const Divider(height: 1, indent: 60, color: kBorder),
                        _AnalysisButton(
                          icon: Icons.accessibility_new_rounded,
                          color: const Color(0xFF38BDF8),
                          title: 'Postural Analysis',
                          subtitle: 'Body alignment screening',
                          onTap: () => Navigator.push(context, _route(const PostureGuideScreen())),
                        ),
                        const Divider(height: 1, indent: 60, color: kBorder),
                        _AnalysisButton(
                          icon: Icons.directions_run_rounded,
                          color: const Color(0xFFFF6B35),
                          title: 'Running Mechanics',
                          subtitle: 'Running form analysis',
                          onTap: () => Navigator.push(context, _route(const RunningAnalysisScreen())),
                        ),
                        const Divider(height: 1, indent: 60, color: kBorder),
                        _AnalysisButton(
                          icon: Icons.sports_cricket_rounded,
                          color: kSleep,
                          title: 'Bowling Mechanics',
                          subtitle: 'Bowling action analysis',
                          onTap: () => Navigator.push(context, _route(const BowlingAnalysisScreen())),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

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

              ],
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

// ── Animated Gauge ────────────────────────────────────────────────────────────

class _SpeedometerGauge extends StatefulWidget {
  final String     value, suffix, label;
  final double     progress;
  final Color      color;
  final IconData   icon;
  final String     maxLabel;
  final VoidCallback onTap;

  const _SpeedometerGauge({
    required this.value,
    required this.suffix,
    required this.label,
    required this.progress,
    required this.color,
    required this.icon,
    this.maxLabel = '100',
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
              builder: (_, __) {
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

  const _SpeedometerPainter({
    required this.animProgress,
    required this.gaugeColor,
    required this.value,
    required this.suffix,
    required this.pulse,
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
          ..color       = Colors.white.withValues(alpha: 0.50 + 0.30 * pulse)
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
      old.gaugeColor   != gaugeColor;
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
        Text('0',      style: const TextStyle(fontSize: 9, color: kTextMuted)),
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
        Text(maxLabel, style: const TextStyle(fontSize: 9, color: kTextMuted)),
      ],
    );
  }
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

// ── Analysis Button ───────────────────────────────────────────────────────────

class _AnalysisButton extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title, subtitle;
  final VoidCallback onTap;

  const _AnalysisButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kTextMuted),
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
