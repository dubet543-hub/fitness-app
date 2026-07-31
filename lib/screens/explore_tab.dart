import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../posture_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import '../services/entitlements.dart';
import '../services/local_log_store.dart';
import '../widgets/feature_gate.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  DateTime? _postureNext;
  DateTime? _runningNext;
  DateTime? _bowlingNext;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final posture = await LocalLogStore.postureNextAvailable();
    final running = await LocalLogStore.runningNextAvailable();
    final bowling = await LocalLogStore.bowlingNextAvailable();
    if (!mounted) return;
    setState(() {
      _postureNext = posture;
      _runningNext = running;
      _bowlingNext = bowling;
      _loading = false;
    });
  }

  bool _isLocked(DateTime? nextAvailable) =>
      nextAvailable != null && DateTime.now().isBefore(nextAvailable);

  /// Runs the tool if it's unlocked; otherwise shows how long until it opens
  /// again, and re-checks the lock state on return (a fresh check just taken
  /// re-locks the card without needing to leave and re-enter this tab).
  Future<void> _openTool(DateTime? nextAvailable, Widget Function() builder,
      String featureKey) async {
    if (_isLocked(nextAvailable)) {
      _showLockedSheet(nextAvailable!);
      return;
    }
    await FeatureGate.push(context, featureKey, builder);
    await _loadLockState();
  }

  void _showLockedSheet(DateTime nextAvailable) {
    final daysLeft = nextAvailable.difference(DateTime.now()).inDays + 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lock_clock_rounded, color: kWarn, size: 22),
              const SizedBox(width: 10),
              Text('Tool locked', style: TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Text(
              'This check runs once every 14 days, so results reflect a real change '
              'rather than day-to-day noise. It opens again in $daysLeft '
              '${daysLeft == 1 ? 'day' : 'days'}.',
              style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: kOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                    'Camera-based movement & technique analysis. Each tool re-opens 14 days after your last check.',
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
              nextAvailable: _postureNext,
              locked: !_loading && _isLocked(_postureNext),
              onTap: () => _openTool(_postureNext, () => PostureGuideScreen(), FeatureKeys.posture),
            ),
            const SizedBox(height: 12),
            _MotionToolCard(
              icon: Icons.directions_run_rounded,
              title: 'Running',
              subtitle: 'Gait, cadence & running form analysis',
              tags: const ['Pose AI', 'Gait'],
              accentColor: kOrange,
              nextAvailable: _runningNext,
              locked: !_loading && _isLocked(_runningNext),
              onTap: () => _openTool(_runningNext, () => const RunningAnalysisScreen(), FeatureKeys.running),
            ),
            const SizedBox(height: 12),
            _MotionToolCard(
              icon: Icons.sports_cricket_rounded,
              title: 'Bowling',
              subtitle: 'Fast & spin action biomechanics',
              tags: const ['Pose AI', 'Technique'],
              accentColor: kSleep,
              nextAvailable: _bowlingNext,
              locked: !_loading && _isLocked(_bowlingNext),
              onTap: () => _openTool(_bowlingNext, () => const BowlingAnalysisScreen(), FeatureKeys.bowling),
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
  final DateTime?    nextAvailable;
  final bool         locked;

  const _MotionToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.accentColor,
    required this.onTap,
    this.nextAvailable,
    this.locked = false,
  });

  String get _statusLabel {
    if (!locked) return nextAvailable == null ? 'Not checked yet' : 'Available now';
    final daysLeft = nextAvailable!.difference(DateTime.now()).inDays + 1;
    return 'Opens in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: locked ? kWarn.withValues(alpha: 0.35) : kBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Opacity(
          opacity: locked ? 0.6 : 1.0,
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
                child: Icon(locked ? Icons.lock_rounded : icon, color: accentColor, size: 26),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          locked ? Icons.lock_clock_rounded : Icons.check_circle_outline_rounded,
                          size: 12,
                          color: locked ? kWarn : kTextMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: locked ? FontWeight.w700 : FontWeight.w400,
                            color: locked ? kWarn : kTextMuted,
                          ),
                        ),
                      ],
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
                child: Icon(
                  locked ? Icons.lock_outline_rounded : Icons.arrow_forward_rounded,
                  color: accentColor, size: 18,
                ),
              ),
            ],
          ),
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
