import 'package:flutter/material.dart';
import '../core/theme.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text(
          'ANALYTICS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stat Cards ─────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _StatCard(label: 'SESSIONS', value: '12', color: const Color(0xFF38BDF8))),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'AVG SCORE', value: '85', color: kAccent)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(label: 'HOURS', value: '8.5', color: const Color(0xFFA78BFA))),
              ],
            ),
            const SizedBox(height: 28),

            // ── Performance Chart ──────────────────────────────────
            const _SectionLabel('PERFORMANCE'),
            const SizedBox(height: 12),
            const _PerformanceChart(),
            const SizedBox(height: 28),

            // ── Breakdown ──────────────────────────────────────────
            const _SectionLabel('BY FEATURE'),
            const SizedBox(height: 12),
            _BreakdownItem(label: 'Running Analysis', percent: 0.87, color: const Color(0xFFFF6B35), trend: _Trend.up),
            const SizedBox(height: 8),
            _BreakdownItem(label: 'Posture Analysis',  percent: 0.92, color: const Color(0xFF38BDF8), trend: _Trend.up),
            const SizedBox(height: 8),
            _BreakdownItem(label: 'Training Load',     percent: 0.74, color: kAccent,                trend: _Trend.stable),
            const SizedBox(height: 8),
            _BreakdownItem(label: 'Bowling Analysis',  percent: 0.68, color: const Color(0xFFA78BFA), trend: _Trend.down),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
  );
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 20, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -1.0)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, color: kTextSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

// ── Performance Chart (area + line + bars) ────────────────────────────────────

class _PerformanceChart extends StatelessWidget {
  const _PerformanceChart();

  static const _data = [0.60, 0.75, 0.65, 0.88, 0.82, 0.91, 0.87];
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final avg = (_data.reduce((a, b) => a + b) / _data.length * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('THIS WEEK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Avg $avg',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _AreaChartPainter(data: _data),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (i) => Expanded(
              child: Text(
                _days[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: i == 6 ? kAccent : kTextMuted,
                  fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> data;
  const _AreaChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final n  = data.length;
    final bw = w / n;

    // ── Grid lines ─────────────────────────────────────────
    final gridPaint = Paint()
      ..color = kBorderBright.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    for (final pct in [0.25, 0.50, 0.75]) {
      final y = h - h * pct;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Bar columns ────────────────────────────────────────
    final barPad = bw * 0.22;
    for (int i = 0; i < n; i++) {
      final isToday = i == n - 1;
      final barH   = data[i] * h;
      final x      = i * bw + barPad;
      final bwInner = bw - barPad * 2;

      final barPaint = Paint()
        ..color = isToday ? kAccent.withValues(alpha: 0.25) : kBorderBright.withValues(alpha: 0.5);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h - barH, bwInner, barH), const Radius.circular(4)),
        barPaint,
      );
    }

    // ── Compute point centers ──────────────────────────────
    final pts = List.generate(n, (i) => Offset(i * bw + bw / 2, h - data[i] * h));

    // ── Area fill (gradient) ───────────────────────────────
    final areaPath = Path()
      ..moveTo(pts[0].dx, h)
      ..lineTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < n - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      areaPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    areaPath
      ..lineTo(pts.last.dx, h)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kAccent.withValues(alpha: 0.22), kAccent.withValues(alpha: 0.01)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── Smooth line ────────────────────────────────────────
    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n - 1; i++) {
      final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
      final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = kAccent.withValues(alpha: 0.7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── Dots ───────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final isToday = i == n - 1;
      if (isToday) {
        // Outer ring
        canvas.drawCircle(pts[i], 6, Paint()..color = kAccent.withValues(alpha: 0.2));
        // Solid dot
        canvas.drawCircle(pts[i], 4, Paint()..color = kAccent);
        // Inner white
        canvas.drawCircle(pts[i], 1.8, Paint()..color = Colors.black);
      } else {
        canvas.drawCircle(pts[i], 2.5, Paint()..color = kBorderBright);
      }
    }

    // ── Score label above today's dot ─────────────────────
    final todayScore = (data[n - 1] * 100).round().toString();
    final tp = TextPainter(
      text: TextSpan(
        text: todayScore,
        style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pts[n - 1].dx - tp.width / 2, pts[n - 1].dy - tp.height - 8));
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) => old.data != data;
}

// ── Breakdown Item ────────────────────────────────────────────────────────────

enum _Trend { up, down, stable }

class _BreakdownItem extends StatelessWidget {
  final String label;
  final double percent;
  final Color  color;
  final _Trend trend;
  const _BreakdownItem({required this.label, required this.percent, required this.color, required this.trend});

  @override
  Widget build(BuildContext context) {
    final trendIcon  = trend == _Trend.up ? Icons.arrow_upward_rounded : trend == _Trend.down ? Icons.arrow_downward_rounded : Icons.remove_rounded;
    final trendColor = trend == _Trend.up ? kAccent : trend == _Trend.down ? const Color(0xFFEF4444) : kTextSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent, minHeight: 4, backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(percent * 100).round()}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(trendIcon, size: 11, color: trendColor),
                  const SizedBox(width: 2),
                  Text('trend', style: TextStyle(fontSize: 9, color: trendColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
