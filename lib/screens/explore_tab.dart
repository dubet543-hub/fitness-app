import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../posture_screen.dart';
import '../training_load_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import 'workload_monitor_screen.dart';
import 'wellness_log_screen.dart';
import 'body_composition_screen.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: const Text(
          'EXPLORE',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
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
            // ── Search ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: const TextField(
                style: TextStyle(color: kTextPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search exercises, drills...',
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: kTextSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Features ────────────────────────────────────────
            const _SectionLabel('FEATURES'),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ExploreFeatureCard(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Posture',
                  subtitle: 'Body alignment',
                  accentColor: const Color(0xFF38BDF8),
                  onTap: () => Navigator.push(context, _route(const PostureGuideScreen())),
                ),
                _ExploreFeatureCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Training Load',
                  subtitle: 'Workload monitor',
                  accentColor: kAccent,
                  onTap: () => Navigator.push(context, _route(const TrainingLoadScreen())),
                ),
                _ExploreFeatureCard(
                  icon: Icons.directions_run_rounded,
                  title: 'Running',
                  subtitle: 'Form analysis',
                  accentColor: const Color(0xFFFF6B35),
                  onTap: () => Navigator.push(context, _route(const RunningAnalysisScreen())),
                ),
                _ExploreFeatureCard(
                  icon: Icons.sports_cricket_rounded,
                  title: 'Bowling',
                  subtitle: 'Technique',
                  accentColor: kSleep,
                  onTap: () => Navigator.push(context, _route(const BowlingAnalysisScreen())),
                ),
                _ExploreFeatureCard(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Workload',
                  subtitle: 'Load monitoring',
                  accentColor: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, _route(const WorkloadMonitorScreen())),
                ),
                _ExploreFeatureCard(
                  icon: Icons.health_and_safety_rounded,
                  title: 'Wellness',
                  subtitle: 'Sleep & Mood',
                  accentColor: const Color(0xFF818CF8),
                  onTap: () => Navigator.push(context, _route(const WellnessLogScreen())),
                ),
                _ExploreFeatureCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Body Comp',
                  subtitle: 'Composition analysis',
                  accentColor: const Color(0xFFF97316),
                  onTap: () => Navigator.push(context, _route(const BodyCompositionScreen())),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Route _route(Widget screen) => MaterialPageRoute(builder: (_) => screen);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
  );
}

class _ExploreFeatureCard extends StatelessWidget {
  final IconData     icon;
  final String       title, subtitle;
  final Color        accentColor;
  final VoidCallback onTap;

  const _ExploreFeatureCard({
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
              width: 38, height: 38,
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
              width: 22, height: 2.5,
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
