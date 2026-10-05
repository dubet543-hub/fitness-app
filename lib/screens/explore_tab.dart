import 'package:flutter/material.dart';
import '../api_service.dart';
import '../core/theme.dart';
import '../posture_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import '../services/entitlements.dart';
import '../services/local_log_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/feature_gate.dart';

/// Client-side kill switch: Bio Lab is held back from the general release
/// while it's finished, but must keep working for the Play Store review
/// account so store review isn't blocked on it. Remove once Bio Lab ships.
const _bioLabPreviewEmails = {'playreview@solidcoreats.com'};

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
  bool _bioLabOpen = false;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final posture = await LocalLogStore.postureNextAvailable();
    final running = await LocalLogStore.runningNextAvailable();
    final bowling = await LocalLogStore.bowlingNextAvailable();
    final user = await ApiService.getCachedUser();
    final open = _bioLabPreviewEmails.contains(user?.email.toLowerCase());
    if (!mounted) return;
    setState(() {
      _postureNext = posture;
      _runningNext = running;
      _bowlingNext = bowling;
      _bioLabOpen = open;
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
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: kBorderBright, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.lock_clock_outlined, color: kTextSecondary, size: 28),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: const Text(
                  'Tool locked',
                  style: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This check runs once every 14 days, so results reflect a real change '
                'rather than day-to-day noise. It opens again in $daysLeft '
                '${daysLeft == 1 ? 'day' : 'days'}.',
                style: const TextStyle(color: kTextSecondary, fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 28),
          children: [
            // ── Header ──────────────────────────────────────────
            Semantics(
              header: true,
              child: const Text(
                'Motion',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.6, height: 1.15),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Camera-based movement and technique analysis. Each tool reopens 14 days after your last check.',
              style: TextStyle(color: kTextSecondary, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 28),

            // ── Tools ───────────────────────────────────────────
            const SectionHeader('Analysis tools'),
            const SizedBox(height: 8),
            if (_loading)
              const SizedBox.shrink()
            else if (!_bioLabOpen)
              const _ComingSoonPanel()
            else
              _Group(
                children: [
                  _MotionToolRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Posture',
                    subtitle: 'Body alignment and postural symmetry check',
                    nextAvailable: _postureNext,
                    locked: _isLocked(_postureNext),
                    onTap: () => _openTool(_postureNext, () => PostureGuideScreen(), FeatureKeys.posture),
                  ),
                  _MotionToolRow(
                    icon: Icons.directions_run_rounded,
                    title: 'Running',
                    subtitle: 'Gait, cadence and running form analysis',
                    nextAvailable: _runningNext,
                    locked: _isLocked(_runningNext),
                    onTap: () => _openTool(_runningNext, () => const RunningAnalysisScreen(), FeatureKeys.running),
                  ),
                  _MotionToolRow(
                    icon: Icons.sports_cricket_rounded,
                    title: 'Bowling',
                    subtitle: 'Fast and spin action biomechanics',
                    nextAvailable: _bowlingNext,
                    locked: _isLocked(_bowlingNext),
                    onTap: () => _openTool(_bowlingNext, () => const BowlingAnalysisScreen(), FeatureKeys.bowling),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the tool rows while Bio Lab is held back from general
/// release — a calm teaser panel rather than an error state.
class _ComingSoonPanel extends StatelessWidget {
  const _ComingSoonPanel();

  @override
  Widget build(BuildContext context) => const _Panel(
    padding: EdgeInsets.fromLTRB(18, 18, 18, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome_outlined, color: kTextSecondary, size: 22),
        SizedBox(height: 12),
        Text(
          'Something big is coming',
          style: TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        SizedBox(height: 6),
        Text(
          'Posture, running and bowling analysis are getting a full rebuild — '
          'sharper pose tracking, clearer breakdowns, faster results. '
          'These tools reopen soon.',
          style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.45),
        ),
      ],
    ),
  );
}

// ── Panel / group ─────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kBorder, width: 0.6),
    ),
    child: Padding(padding: padding, child: SizedBox(width: double.infinity, child: child)),
  );
}

/// One card holding a list of rows separated by hairlines inset to the text.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorder, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 54),
                child: Divider(height: 0.6, thickness: 0.6, color: kBorder),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MotionToolRow extends StatelessWidget {
  final IconData     icon;
  final String       title, subtitle;
  final VoidCallback onTap;
  final DateTime?    nextAvailable;
  final bool         locked;

  const _MotionToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
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
    final status = _statusLabel;
    return Semantics(
      button: true,
      label: '$title. $subtitle. $status.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () { hapticSelect(); onTap(); },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 22, color: locked ? kTextMuted : kTextSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: locked ? kTextSecondary : kTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: kTextSecondary, fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (locked) ...[
                          const Icon(Icons.lock_clock_outlined, size: 14, color: kWarn),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: locked ? kTextSecondary : kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                  size: locked ? 18 : 20,
                  color: kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
