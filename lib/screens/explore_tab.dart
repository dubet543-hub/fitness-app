import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../posture_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text(
          'BIO LAB',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero header ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kAccent.withValues(alpha: 0.16), kCard],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.center_focus_strong_rounded, color: kAccent, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bio Lab',
                          style: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Camera-based movement & technique analysis. Pick a tool, record your action, and get instant pose-driven feedback.',
                    style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ── Tools ───────────────────────────────────────────
            const _SectionLabel('ANALYSIS TOOLS'),
            const SizedBox(height: 14),
            _MotionToolCard(
              icon: Icons.accessibility_new_rounded,
              title: 'Posture',
              subtitle: 'Body alignment & postural symmetry check',
              tags: const ['Pose AI', 'Alignment'],
              accentColor: kSky,
              onTap: () => FeatureGate.push(context, FeatureKeys.posture, () => PostureGuideScreen()),
            ),
            const SizedBox(height: 12),
            _MotionToolCard(
              icon: Icons.directions_run_rounded,
              title: 'Running',
              subtitle: 'Gait, cadence & running form analysis',
              tags: const ['Pose AI', 'Gait'],
              accentColor: kOrange,
              onTap: () => FeatureGate.push(context, FeatureKeys.running, () => const RunningAnalysisScreen()),
            ),
            const SizedBox(height: 12),
            _MotionToolCard(
              icon: Icons.sports_cricket_rounded,
              title: 'Bowling',
              subtitle: 'Fast & spin action biomechanics',
              tags: const ['Pose AI', 'Technique'],
              accentColor: kSleep,
              onTap: () => FeatureGate.push(context, FeatureKeys.bowling, () => const BowlingAnalysisScreen()),
            ),
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
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
  );
}

class _MotionToolCard extends StatelessWidget {
  final IconData     icon;
  final String       title, subtitle;
  final List<String> tags;
  final Color        accentColor;
  final VoidCallback onTap;

  const _MotionToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Gradient icon tile
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.30),
                    accentColor.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: kTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: kTextSecondary, fontSize: 11.5, height: 1.3),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((t) => _Tag(text: t, color: accentColor)).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded, color: accentColor, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    );
  }
}
