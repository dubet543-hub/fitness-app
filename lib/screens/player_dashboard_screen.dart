import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../posture_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import 'body_composition_screen.dart';

// ── Aliases ───────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// PlayerDashboardScreen — Analysis Results
// Motion-lab analyses (posture, running, bowling) are shown empty for now —
// no demo data. Body composition shows the user's current saved result.
// ─────────────────────────────────────────────────────────────────────────────

class PlayerDashboardScreen extends StatefulWidget {
  /// Which tab to open first: 0 = Posture, 1 = Running, 2 = Bowling, 3 = Body.
  final int initialTab;
  const PlayerDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<PlayerDashboardScreen> createState() => _PDS();
}

class _PDS extends State<PlayerDashboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('ANALYSIS RESULTS',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: kTextSecondary, letterSpacing: 1.4)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kTextPrimary,
            unselectedLabelColor: kTextMuted,
            indicatorColor: kAccent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(icon: Icon(Icons.accessibility_new_rounded, size: 15), text: 'Posture'),
              Tab(icon: Icon(Icons.directions_run_rounded, size: 15),    text: 'Running'),
              Tab(icon: Icon(Icons.sports_cricket_rounded, size: 15),    text: 'Bowling'),
              Tab(icon: Icon(Icons.person_outline_rounded, size: 15),    text: 'Body Comp'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MotionLabEmpty(
            icon: Icons.accessibility_new_rounded,
            accent: kSky,
            title: 'No posture result yet',
            hint: 'Run a postural analysis to see your alignment results here.',
            runLabel: 'Run Postural Analysis',
            builder: () => PostureGuideScreen(),
          ),
          _MotionLabEmpty(
            icon: Icons.directions_run_rounded,
            accent: kOrange,
            title: 'No running result yet',
            hint: 'Record a running analysis to see your mechanics here.',
            runLabel: 'Run Running Analysis',
            builder: () => const RunningAnalysisScreen(),
          ),
          _MotionLabEmpty(
            icon: Icons.sports_cricket_rounded,
            accent: kSleep,
            title: 'No bowling result yet',
            hint: 'Record a bowling analysis to see your action here.',
            runLabel: 'Run Bowling Analysis',
            builder: () => const BowlingAnalysisScreen(),
          ),
          const BodyCompositionScreen(embedded: true),
        ],
      ),
    );
  }
}

// ── Motion-lab empty state (no demo data) ─────────────────────────────────────

class _MotionLabEmpty extends StatelessWidget {
  final IconData icon;
  final Color    accent;
  final String   title, hint, runLabel;
  final Widget Function() builder;

  const _MotionLabEmpty({
    required this.icon,
    required this.accent,
    required this.title,
    required this.hint,
    required this.runLabel,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 30, color: accent),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: kTextSecondary, height: 1.4)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => builder())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.play_arrow_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(runLabel,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
