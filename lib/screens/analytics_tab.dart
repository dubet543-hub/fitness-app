import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: kTextSecondary),
                SizedBox(width: 6),
                Text('This Week', style: TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextSecondary),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Sessions', value: '12', icon: Icons.play_circle_outline_rounded, color: const Color(0xFF38BDF8))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Avg Score', value: '85', icon: Icons.stars_rounded, color: kAccent)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Hours', value: '8.5', icon: Icons.timer_outlined, color: const Color(0xFF34D399))),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader('Performance Overview'),
            const SizedBox(height: 14),
            const _PerformanceChart(),
            const SizedBox(height: 24),
            const SectionHeader('Breakdown by Feature'),
            const SizedBox(height: 14),
            _BreakdownItem(label: 'Running Analysis', percent: 0.87, color: const Color(0xFFFB923C)),
            const SizedBox(height: 10),
            _BreakdownItem(label: 'Posture Analysis', percent: 0.92, color: const Color(0xFF38BDF8)),
            const SizedBox(height: 10),
            _BreakdownItem(label: 'Training Load', percent: 0.74, color: const Color(0xFF34D399)),
            const SizedBox(height: 10),
            _BreakdownItem(label: 'Bowling Analysis', percent: 0.68, color: const Color(0xFFC084FC)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final Color    color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }
}

class _PerformanceChart extends StatelessWidget {
  const _PerformanceChart();

  static const _data = [0.6, 0.75, 0.65, 0.88, 0.82, 0.91, 0.87];
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: _data[i] * 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: isToday
                                  ? [kAccent, kAccent.withValues(alpha: 0.5)]
                                  : [kBorderBright, kBorder],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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

class _BreakdownItem extends StatelessWidget {
  final String label;
  final double percent;
  final Color  color;
  const _BreakdownItem({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary)),
              Text('${(percent * 100).round()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent, minHeight: 6, backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
