import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../posture_screen.dart';
import '../running_analysis_screen.dart';
import '../bowling_analysis_screen.dart';
import '../services/local_log_store.dart';
import 'body_composition_screen.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayerDashboardScreen — Analysis Results
// Posture, running, and bowling each show the most recent locally-saved
// result (LocalLogStore), or a "run an analysis" prompt if there isn't one
// yet. Body composition shows the user's current saved result the same way,
// via its own embedded history loading.
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

  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _postureHistory = [];
  List<Map<String, dynamic>> _runningHistory = [];
  List<Map<String, dynamic>> _bowlingHistory = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      // A hung Future (as opposed to one that throws) would otherwise spin
      // this screen forever with no way out — bound it like the API calls.
      final results = await Future.wait([
        LocalLogStore.postureHistory(),
        LocalLogStore.runningHistory(),
        LocalLogStore.bowlingHistory(),
      ]).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _postureHistory = results[0];
        _runningHistory = results[1];
        _bowlingHistory = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  /// Opens an analysis screen, then reloads history so a fresh result
  /// replaces the empty state or the previous one as soon as we're back.
  Future<void> _runThen(String feature, Widget Function() builder) async {
    // Gated: locked features show the upgrade sheet instead of the tool.
    await FeatureGate.push(context, feature, builder);
    await _loadHistory();
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 0),
              child: Semantics(
                header: true,
                child: const Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.6, height: 1.15),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(kGutter, 4, kGutter, 10),
              child: Text(
                'Your latest analysis results',
                style: TextStyle(fontSize: 15, color: kTextSecondary),
              ),
            ),

            // ── Tabs ──────────────────────────────────────────────────────
            // Plain text tabs; colours, underline and type come from the theme.
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.only(left: kGutter - 12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: (_) => hapticSelect(),
              tabs: const [
                Tab(text: 'Posture'),
                Tab(text: 'Running'),
                Tab(text: 'Bowling'),
                Tab(text: 'Body comp'),
              ],
            ),
            const Divider(height: 0.6, thickness: 0.6, color: kBorder),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _loadError != null
                  ? _EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load your saved results',
                      hint: _loadError!,
                      action: OutlinedButton(
                        onPressed: () { hapticSelect(); _loadHistory(); },
                        child: const Text('Try again'),
                      ),
                    )
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _postureHistory.isEmpty
                            ? _MotionLabEmpty(
                                icon: Icons.accessibility_new_rounded,
                                title: 'No posture result yet',
                                hint: 'Run a postural analysis to see your alignment results here.',
                                runLabel: 'Run postural analysis',
                                onRun: () => _runThen(FeatureKeys.posture, () => PostureGuideScreen()),
                              )
                            : _PostureResultSummary(
                                entry: _postureHistory.last,
                                onRun: () => _runThen(FeatureKeys.posture, () => PostureGuideScreen()),
                              ),
                        _runningHistory.isEmpty
                            ? _MotionLabEmpty(
                                icon: Icons.directions_run_rounded,
                                title: 'No running result yet',
                                hint: 'Record a running analysis to see your mechanics here.',
                                runLabel: 'Run running analysis',
                                onRun: () => _runThen(FeatureKeys.running, () => const RunningAnalysisScreen()),
                              )
                            : _RunningResultSummary(
                                entry: _runningHistory.last,
                                onRun: () => _runThen(FeatureKeys.running, () => const RunningAnalysisScreen()),
                              ),
                        _bowlingHistory.isEmpty
                            ? _MotionLabEmpty(
                                icon: Icons.sports_cricket_rounded,
                                title: 'No bowling result yet',
                                hint: 'Record a bowling analysis to see your action here.',
                                runLabel: 'Run bowling analysis',
                                onRun: () => _runThen(FeatureKeys.bowling, () => const BowlingAnalysisScreen()),
                              )
                            : _BowlingResultSummary(
                                entry: _bowlingHistory.last,
                                onRun: () => _runThen(FeatureKeys.bowling, () => const BowlingAnalysisScreen()),
                              ),
                        const BodyCompositionScreen(embedded: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared date formatting ─────────────────────────────────────────────────

String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

double _num(dynamic v) => v is num ? v.toDouble() : 0.0;

/// Capitalises the first letter of a stored lowercase token, e.g. "midfoot".
String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title, hint;
  final Widget   action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: kTextMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            action,
          ],
        ),
      ),
    );
  }
}

class _MotionLabEmpty extends StatelessWidget {
  final IconData icon;
  final String   title, hint, runLabel;
  final VoidCallback onRun;

  const _MotionLabEmpty({
    required this.icon,
    required this.title,
    required this.hint,
    required this.runLabel,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: icon,
      title: title,
      hint: hint,
      action: ElevatedButton(
        onPressed: () { hapticConfirm(); onRun(); },
        child: Text(runLabel),
      ),
    );
  }
}

// ── Shared "latest result" scaffold ─────────────────────────────────────────

class _MotionLabResult extends StatelessWidget {
  final String title;
  final String date;
  final List<(String, String)> metrics;
  final String runLabel;
  final VoidCallback onRun;

  const _MotionLabResult({
    required this.title,
    required this.date,
    required this.metrics,
    required this.runLabel,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(kGutter, 20, kGutter, 28),
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4),
          ),
        ),
        if (date.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(date, style: const TextStyle(fontSize: 14, color: kTextSecondary)),
        ],
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kBorder, width: 0.6),
          ),
          child: Column(
            children: [
              for (int i = 0; i < metrics.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Divider(height: 0.6, thickness: 0.6, color: kBorder),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(metrics[i].$1, style: const TextStyle(fontSize: 15, color: kTextSecondary)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          metrics[i].$2,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () { hapticSelect(); onRun(); },
          child: Text(runLabel),
        ),
      ],
    );
  }
}

// ── Posture ──────────────────────────────────────────────────────────────────

class _PostureResultSummary extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onRun;
  const _PostureResultSummary({required this.entry, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final mode = entry['mode'] == 'sagittal' ? 'Sagittal' : 'Frontal';
    final results = (entry['results'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return _MotionLabResult(
      title: '$mode posture screen',
      date: _fmtDate(entry['date'] as String? ?? ''),
      metrics: results
          .map((r) => ((r['label'] ?? '').toString(), (r['value'] ?? '').toString()))
          .toList(),
      runLabel: 'Run postural analysis',
      onRun: onRun,
    );
  }
}

// ── Running ──────────────────────────────────────────────────────────────────

class _RunningResultSummary extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onRun;
  const _RunningResultSummary({required this.entry, required this.onRun});

  @override
  Widget build(BuildContext context) {
    return _MotionLabResult(
      title: 'Running form analysis',
      date: _fmtDate(entry['date'] as String? ?? ''),
      metrics: [
        ('Trunk lean',     '${_num(entry['trunkLean']).toStringAsFixed(1)}°'),
        ('Knee drive',     '${_num(entry['kneeDrive']).toStringAsFixed(0)}%'),
        ('Hip drop',       '${_num(entry['hipDrop']).toStringAsFixed(1)}%'),
        ('Arm swing',      '${_num(entry['armSwing']).toStringAsFixed(1)}°'),
        ('Head position',  '${_num(entry['headPosition']).toStringAsFixed(1)}°'),
        ('Foot strike',    entry['footStrike'] == null ? '—' : _cap('${entry['footStrike']}')),
        ('Cadence',        '${_num(entry['cadence']).toStringAsFixed(0)} steps/min'),
        ('Overall score',  '${_num(entry['overallScore']).toStringAsFixed(0)}/100'),
      ],
      runLabel: 'Run running analysis',
      onRun: onRun,
    );
  }
}

// ── Bowling ──────────────────────────────────────────────────────────────────

class _BowlingResultSummary extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onRun;
  const _BowlingResultSummary({required this.entry, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final isFast = entry['type'] != 'spin';
    return _MotionLabResult(
      title: isFast ? 'Fast bowling analysis' : 'Spin bowling analysis',
      date: _fmtDate(entry['date'] as String? ?? ''),
      metrics: [
        ('Trunk lean',       '${_num(entry['trunkLean']).toStringAsFixed(1)}°'),
        ('Bowling arm arc',  '${_num(entry['armArc']).toStringAsFixed(1)}°'),
        ('Front knee angle', '${_num(entry['frontKnee']).toStringAsFixed(1)}°'),
        ('Head position',    '${_num(entry['headPosition']).toStringAsFixed(1)}°'),
        ('Shoulder tilt',    '${_num(entry['bodyTilt']).toStringAsFixed(1)}°'),
      ],
      runLabel: 'Run bowling analysis',
      onRun: onRun,
    );
  }
}
