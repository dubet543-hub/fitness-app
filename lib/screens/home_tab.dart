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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _WhoopRing(
                          value: '74',
                          suffix: '%',
                          label: 'SLEEP',
                          progress: 0.74,
                          color: kSleep,
                          onTap: () => Navigator.push(context, _route(const SleepMonitorScreen())),
                        ),
                      ),
                      Expanded(
                        child: _WhoopRing(
                          value: '78',
                          suffix: '%',
                          label: 'RECOVERY',
                          progress: 0.78,
                          color: kAccent,
                          onTap: () {},
                        ),
                      ),
                      Expanded(
                        child: _WhoopRing(
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

// ── Whoop-style Ring Gauge ────────────────────────────────────────────────────

class _WhoopRing extends StatelessWidget {
  final String value, suffix, label;
  final double progress;
  final Color  color;
  final VoidCallback onTap;

  const _WhoopRing({
    required this.value,
    required this.suffix,
    required this.label,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(96, 96),
                  painter: _RingPainter(
                    progress: progress.clamp(0.0, 1.0),
                    trackColor: color.withValues(alpha: 0.14),
                    ringColor: color,
                    strokeWidth: 8.5,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                              letterSpacing: -0.5,
                              height: 1,
                            ),
                          ),
                          if (suffix.isNotEmpty)
                            TextSpan(
                              text: suffix,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kTextSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress, strokeWidth;
  final Color  trackColor, ringColor;
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    const start  = -pi / 2;        // top
    const sweep  = 2 * pi;         // full circle

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()..color = trackColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, sweep * progress, false,
        Paint()
          ..color = ringColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep * progress,
            colors: [ringColor.withValues(alpha: 0.6), ringColor],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
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
