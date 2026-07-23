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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: kDanger),
                    const SizedBox(height: 12),
                    Text('Could not load your saved results',
                        style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(_loadError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kTextSecondary, fontSize: 12.5)),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _loadHistory, child: const Text('Try Again')),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _postureHistory.isEmpty
                    ? _MotionLabEmpty(
                        icon: Icons.accessibility_new_rounded,
                        accent: kSky,
                        title: 'No posture result yet',
                        hint: 'Run a postural analysis to see your alignment results here.',
                        runLabel: 'Run Postural Analysis',
                        onRun: () => _runThen(FeatureKeys.posture, () => PostureGuideScreen()),
                      )
                    : _PostureResultSummary(
                        entry: _postureHistory.last,
                        onRun: () => _runThen(FeatureKeys.posture, () => PostureGuideScreen()),
                      ),
                _runningHistory.isEmpty
                    ? _MotionLabEmpty(
                        icon: Icons.directions_run_rounded,
                        accent: kOrange,
                        title: 'No running result yet',
                        hint: 'Record a running analysis to see your mechanics here.',
                        runLabel: 'Run Running Analysis',
                        onRun: () => _runThen(FeatureKeys.running, () => const RunningAnalysisScreen()),
                      )
                    : _RunningResultSummary(
                        entry: _runningHistory.last,
                        onRun: () => _runThen(FeatureKeys.running, () => const RunningAnalysisScreen()),
                      ),
                _bowlingHistory.isEmpty
                    ? _MotionLabEmpty(
                        icon: Icons.sports_cricket_rounded,
                        accent: kSleep,
                        title: 'No bowling result yet',
                        hint: 'Record a bowling analysis to see your action here.',
                        runLabel: 'Run Bowling Analysis',
                        onRun: () => _runThen(FeatureKeys.bowling, () => const BowlingAnalysisScreen()),
                      )
                    : _BowlingResultSummary(
                        entry: _bowlingHistory.last,
                        onRun: () => _runThen(FeatureKeys.bowling, () => const BowlingAnalysisScreen()),
                      ),
                const BodyCompositionScreen(embedded: true),
              ],
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

// ── Motion-lab empty state ──────────────────────────────────────────────────

class _MotionLabEmpty extends StatelessWidget {
  final IconData icon;
  final Color    accent;
  final String   title, hint, runLabel;
  final VoidCallback onRun;

  const _MotionLabEmpty({
    required this.icon,
    required this.accent,
    required this.title,
    required this.hint,
    required this.runLabel,
    required this.onRun,
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
            _RunButton(accent: accent, label: runLabel, onTap: onRun),
          ],
        ),
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  final Color accent;
  final String label;
  final VoidCallback onTap;
  const _RunButton({required this.accent, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
        ]),
      ),
    );
  }
}

// ── Shared "latest result" scaffold ─────────────────────────────────────────

class _MotionLabResult extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String date;
  final List<(String, String)> metrics;
  final String runLabel;
  final VoidCallback onRun;

  const _MotionLabResult({
    required this.icon,
    required this.accent,
    required this.title,
    required this.date,
    required this.metrics,
    required this.runLabel,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  Text(date, style: TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(metrics.length, (i) {
                final (label, value) = metrics[i];
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(children: [
                      Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: kTextSecondary))),
                      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
                    ]),
                  ),
                  if (i < metrics.length - 1) Divider(height: 1, color: kBorder),
                ]);
              }),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: _RunButton(accent: accent, label: runLabel, onTap: onRun)),
        ],
      ),
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
      icon: Icons.accessibility_new_rounded,
      accent: kSky,
      title: '$mode Posture Screen',
      date: _fmtDate(entry['date'] as String? ?? ''),
      metrics: results
          .map((r) => ((r['label'] ?? '').toString(), (r['value'] ?? '').toString()))
          .toList(),
      runLabel: 'Run Postural Analysis',
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
      icon: Icons.directions_run_rounded,
      accent: kOrange,
      title: 'Running Form Analysis',
      date: _fmtDate(entry['date'] as String? ?? ''),
      metrics: [
        ('Trunk Lean',     '${_num(entry['trunkLean']).toStringAsFixed(1)}°'),
        ('Knee Drive',     '${_num(entry['kneeDrive']).toStringAsFixed(0)}%'),
        ('Hip Drop',       '${_num(entry['hipDrop']).toStringAsFixed(1)}%'),
        ('Arm Swing',      '${_num(entry['armSwing']).toStringAsFixed(1)}°'),
        ('Head Position',  '${_num(entry['headPosition']).toStringAsFixed(1)}°'),
        ('Foot Strike',    '${entry['footStrike'] ?? '—'}'),
        ('Cadence',        '${_num(entry['cadence']).toStringAsFixed(0)} steps/min'),
        ('Overall Score',  '${_num(entry['overallScore']).toStringAsFixed(0)}/100'),
      ],
      runLabel: 'Run Running Analysis',
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
      icon: Icons.sports_cricket_rounded,
      accent: kSleep,
      title: isFast ? 'Fast Bowling Analysis' : 'Spin Bowling Analysis',
      date: _fmtDate(entry['date'] as String? ?? ''),
      metrics: [
        ('Trunk Lean',    '${_num(entry['trunkLean']).toStringAsFixed(1)}°'),
        ('Bowling Arm Arc', '${_num(entry['armArc']).toStringAsFixed(1)}°'),
        ('Front Knee Angle', '${_num(entry['frontKnee']).toStringAsFixed(1)}°'),
        ('Head Position', '${_num(entry['headPosition']).toStringAsFixed(1)}°'),
        ('Shoulder Tilt',  '${_num(entry['bodyTilt']).toStringAsFixed(1)}°'),
      ],
      runLabel: 'Run Bowling Analysis',
      onRun: onRun,
    );
  }
}
