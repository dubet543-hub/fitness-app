import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../api_service.dart';
import '../services/dashboard_metrics.dart';
import '../services/sleep_metrics.dart';
import '../widgets/common_widgets.dart';
import 'workload_monitor_screen.dart';
import '../services/entitlements.dart';
import '../widgets/feature_gate.dart';

// ── Data Models & series ────────────────────────────────────────────────────────
// The workload / recovery models live in dashboard_metrics.dart (single source
// of truth shared with the home dashboard rings). The series themselves are
// computed there from the signed-in athlete's real synced sessions and loaded
// via AthleteMetricsService. Aliased so this screen's references stay short.

typedef _WP = WorkPoint;
typedef _RP = RecoveryPoint;

// ── Screen ────────────────────────────────────────────────────────────────────

class PlayerStatsScreen extends StatefulWidget {
  /// Which tab to open first: 0 = Performance, 1 = Recovery, 2 = Today.
  final int initialTab;
  const PlayerStatsScreen({super.key, this.initialTab = 0});

  @override
  State<PlayerStatsScreen> createState() => _PDS();
}

class _PDS extends State<PlayerStatsScreen> with SingleTickerProviderStateMixin {
  String _athleteLabel = 'Athlete';
  String _range   = '28d';
  AthleteMetrics? _metrics; // null while the initial load is in flight
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    // Identity chip only — the API is JWT-scoped, so every series below is
    // already the signed-in athlete's own data. No client-side selection.
    ApiService.getCachedUser().then((u) {
      if (u == null || !mounted) return;
      setState(() => _athleteLabel = u.name);
    });
    AthleteMetricsService.load().then((m) {
      if (!mounted) return;
      setState(() => _metrics = m);
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _metrics = AthleteMetrics.empty);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  AthleteMetrics get _m => _metrics ?? AthleteMetrics.empty;

  List<_WP> _filter(List<_WP> all) {
    final n = _range == '7d' ? 7 : _range == '14d' ? 14 : 28;
    return all.sublist(max(0, all.length - n));
  }

  List<_WP> get _trainData => _filter(_m.train);
  List<_WP> get _skillData => _filter(_m.skill);
  List<_WP> get _totalData => _filter(_m.total);
  List<_RP> get _wellData  => _m.recovery;
  List<SleepNight> get _sleepData => _m.sleep;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _athleteToggle()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder, width: 0.6)),
            ),
            child: TabBar(
              controller: _tabs,
              onTap: (_) => hapticSelect(),
              tabs: const [
                Tab(text: 'Performance'),
                Tab(text: 'Recovery'),
                Tab(text: 'Today'),
              ],
            ),
          ),
        ),
      ),
      body: _metrics == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : TabBarView(
              controller: _tabs,
              children: [_performanceTab(), _recoveryTab(), _todayTab()],
            ),
    );
  }

  // ── Performance Tab ────────────────────────────────────────────────────────

  Widget _performanceTab() {
    if (!_m.hasLoadData || _totalData.isEmpty) {
      return _emptyState(
        icon: Icons.show_chart_rounded,
        title: 'No training data yet',
        hint: 'Log sessions to see your workload stats here.',
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rangeBar(),
          const SizedBox(height: 16),
          _acwrPanel('Training workload', _trainData, kSky),
          const SizedBox(height: 12),
          _acwrPanel('Skill workload',    _skillData, kSuccess),
          const SizedBox(height: 12),
          _acwrPanel('Daily total',       _totalData, kViolet),
          const SizedBox(height: 28),

          const SectionHeader('Load vs exertion'),
          const SizedBox(height: 8),
          _loadExertionPanel('Training load vs exertion', _trainData, kSky),
          const SizedBox(height: 12),
          _loadExertionPanel('Skill load vs exertion',    _skillData, kSuccess),
          const SizedBox(height: 12),
          _loadExertionPanel('Daily load vs exertion',    _totalData, kViolet),
        ],
      ),
    );
  }

  Widget _loadExertionPanel(String title, List<_WP> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seriesTitle(title, color),
      const SizedBox(height: 8),
      Wrap(spacing: 16, runSpacing: 6, children: [
        _ldot(color,             'Load'),
        _ldot(Colors.pinkAccent, 'Exertion'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 130,
        child: CustomPaint(
          painter: _LoadExertionPainter(data: data, barColor: color),
          size: Size.infinite,
        ),
      ),
    ]));
  }

  Widget _acwrPanel(String title, List<_WP> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();
    final last   = data.last;
    final zColor = _acwrColor(last.acwr);
    final zLabel = _acwrZone(last.acwr);
    return Semantics(
      button: true,
      hint: 'Opens workload monitor',
      child: _panel(
        onTap: () => FeatureGate.push(context, FeatureKeys.workloadMonitoring,
            () => const WorkloadMonitorScreen()),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _seriesTitle(title, color)),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kTextMuted),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: last.acwr.toStringAsFixed(2), style: _kHeroValue),
              const TextSpan(text: '  ACWR', style: _kUnit),
            ])),
            const Spacer(),
            _StatusDot(color: zColor, label: zLabel),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: CustomPaint(
              painter: _AcwrSparkPainter(data: data, color: color),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _statPill('Load', last.load > 0 ? last.load.toStringAsFixed(0) : '—')),
            Expanded(child: _statPill('Exertion', last.exertion.toStringAsFixed(1))),
          ]),
        ]),
      ),
    );
  }

  // ── Recovery Tab ──────────────────────────────────────────────────────────

  Widget _recoveryTab() {
    if (!_m.hasRecoveryData) {
      return _emptyState(
        icon: Icons.favorite_outline_rounded,
        title: 'No recovery data yet',
        hint: 'Complete a wellness check-in to see your recovery stats here.',
      );
    }
    final well   = _wellData;
    final last7  = well.sublist(max(0, well.length - 7));
    final avgPct = last7.map((r) => r.readinessPct).reduce((a, b) => a + b) / last7.length;
    final todayR = well.last.readinessPct;
    final rColor = todayR >= 0.60 ? kAccent : todayR >= 0.35 ? kWarn : kDanger;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Readiness score card
        _panel(child: Row(children: [
          Semantics(
            label: 'Readiness ${(avgPct * 100).round()} percent',
            excludeSemantics: true,
            child: SizedBox(
              width: 88, height: 88,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(
                  painter: _ReadinessRingPainter(pct: avgPct, color: rColor),
                  size: const Size(88, 88),
                ),
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '${(avgPct * 100).round()}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary,
                        letterSpacing: -0.8, height: 1),
                  ),
                  const TextSpan(text: '%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary)),
                ])),
              ]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Readiness score', style: _kLabel),
            const SizedBox(height: 4),
            Text(_readinessLabel(avgPct),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Text('7-day avg · Today ${(todayR * 100).round()}%',
                style: const TextStyle(fontSize: 13, color: kTextSecondary)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 6, children: [
              _microBadge('Sleep',    well.last.sleep),
              _microBadge('Wellness', well.last.wellness),
              _microBadge('Soreness', well.last.soreness),
              _microBadge('Fatigue',  well.last.fatigue),
            ]),
          ])),
        ])),
        const SizedBox(height: 12),

        // Cumulative recovery score (PDF: total of 4 metrics, lines at 8 & 13)
        // Sliced to the last 14 check-ins so the chart keeps its density now
        // that the real series can span up to ~90 days.
        _cumulativeScorePanel(well.sublist(max(0, well.length - 14))),
        const SizedBox(height: 12),

        // Sleep summary (efficiency, debt, overall summary)
        _sleepData.isEmpty ? _noSleepNote() : _sleepSummaryPanel(_sleepData),
        const SizedBox(height: 12),

        _metricBars('Sleep quality',   well.map((r) => r.sleep).toList(),    kSleep,  well.map((r) => r.d).toList()),
        const SizedBox(height: 12),
        _metricBars('Wellness',        well.map((r) => r.wellness).toList(), kAccent, well.map((r) => r.d).toList()),
        const SizedBox(height: 12),
        _metricBars('Muscle soreness', well.map((r) => r.soreness).toList(), kWarn,   well.map((r) => r.d).toList()),
        const SizedBox(height: 12),
        _metricBars('Fatigue',         well.map((r) => r.fatigue).toList(),  kDanger, well.map((r) => r.d).toList()),
      ]),
    );
  }

  Widget _metricBars(String title, List<int> values, Color color, List<String> dates) {
    final last7v = values.sublist(max(0, values.length - 7));
    final last7d = dates.sublist(max(0, dates.length - 7));
    final cur    = last7v.last;
    final col    = cur <= 2 ? kAccent : cur == 3 ? kWarn : kDanger;
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _seriesTitle(title, color)),
        const SizedBox(width: 8),
        _StatusDot(color: col, label: '$cur — ${_ratingLabel(cur)}'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        // Bars get 68px of height (top 16 for the value labels, bottom 20 for
        // the day labels), so one point of score is worth ~15px of bar.
        height: 104,
        child: CustomPaint(
          painter: _MetricBarsPainter(values: last7v, labels: last7d, color: color),
          size: Size.infinite,
        ),
      ),
    ]));
  }

  // ── Cumulative Recovery Score Panel ─────────────────────────────────────────

  Widget _cumulativeScorePanel(List<_RP> well) {
    final totals = well.map((r) => r.sleep + r.wellness + r.soreness + r.fatigue).toList();
    final cur    = totals.last;
    final col    = cur <= 8 ? kAccent : cur <= 13 ? kWarn : kDanger;
    final zone   = cur <= 8 ? 'Optimal recovery' : cur <= 13 ? 'Monitor — moderate load' : 'High exertion — intervene';
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardTitle('Cumulative recovery score'),
      const SizedBox(height: 10),
      Row(children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: '$cur', style: _kHeroValue),
          const TextSpan(text: ' / 20', style: _kUnit),
        ])),
        const SizedBox(width: 12),
        Flexible(child: _StatusDot(color: col, label: zone, flexible: true)),
      ]),
      const SizedBox(height: 4),
      const Text('Total of Sleep + Wellness + Soreness + Fatigue',
          style: TextStyle(fontSize: 13, color: kTextSecondary)),
      const SizedBox(height: 14),
      SizedBox(
        height: 150,
        child: CustomPaint(
          painter: _CumulativeScorePainter(totals: totals, dates: well.map((r) => r.d).toList()),
          size: Size.infinite,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        _ldot(kAccent, '≤ 8 Optimal'),
        _ldot(kWarn,   '8–13 Caution'),
        _ldot(kDanger, '> 13 Risk'),
      ]),
    ]));
  }

  // ── Sleep Summary Panel ─────────────────────────────────────────────────────

  Widget _sleepSummaryPanel(List<SleepNight> sleep) {
    // All four headline figures come straight from the sheet formulae:
    // sleep time (1), 7-day average (3), efficiency (5) and sleep debt (6).
    final i       = sleep.length - 1;
    final last    = sleep[i];
    final avgMins = averageSleepMinutes(sleep, i);   // null until 7 nights are logged
    final debt    = sleepDebtMinutes(sleep, i);      // null = no avg yet, or no debt that night
    final effPct  = last.efficiency * 100;

    final effCol  = effPct >= 85 ? kAccent : effPct >= 75 ? kWarn : kDanger;
    // Debt is measured against the athlete's own weekly average, so an hour
    // behind is already meaningful — much tighter thresholds than a fixed need.
    final debtCol = debt == null || debt <= 30
        ? kAccent
        : debt <= 60 ? kWarn : kDanger;

    final summary = avgMins == null
        ? 'Log 7 nights of sleep to unlock your rolling 7-day average and sleep debt.'
        : effPct >= 85 && (debt ?? 0) <= 30
            ? 'Sleep is restorative — efficiency is high and last night held the weekly average. Maintain current routine.'
            : (debt ?? 0) > 60
                ? 'Last night fell more than an hour below the 7-day average. Prioritise an earlier bedtime tonight and a recovery nap.'
                : 'Sleep is adequate but inconsistent. Aim for steadier bedtimes to lift efficiency and clear debt.';

    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _cardTitle('Sleep summary')),
        Text('In bed ${formatHhMm(last.timeInBedMinutes)}',
            style: const TextStyle(fontSize: 13, color: kTextSecondary)),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _sleepStat('Sleep time', formatHhMm(last.sleepMinutes), 'last night')),
        const SizedBox(width: 12),
        Expanded(child: _sleepStat(
          '7-day average',
          avgMins == null ? '—' : formatHhMm(avgMins),
          avgMins == null ? 'needs 7 nights' : 'rolling',
        )),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _sleepStat('Efficiency', '${effPct.toStringAsFixed(0)}%', 'asleep / in bed',
            status: effCol)),
        const SizedBox(width: 12),
        Expanded(child: _sleepStat(
          'Sleep debt',
          debt == null ? '—' : formatHhMm(debt),
          avgMins == null ? 'needs 7 nights' : (debt == null ? 'at or above avg' : 'vs 7-day avg'),
          // No dot until there is a 7-day average to measure debt against.
          status: avgMins == null ? null : debtCol,
        )),
      ]),
      const SizedBox(height: 16),
      const Divider(height: 0.6, thickness: 0.6, color: kBorder),
      const SizedBox(height: 14),
      Text(summary, style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.45)),
    ]));
  }

  /// One sleep figure: label (with a status dot when it carries a verdict),
  /// value, and a small qualifier underneath.
  Widget _sleepStat(String label, String value, String sub, {Color? status}) => MergeSemantics(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (status != null) ...[_dot(status), const SizedBox(width: 6)],
        Flexible(child: Text(label, style: _kLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary,
          letterSpacing: -0.6, height: 1.1, fontFeatures: _kTabular)),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(fontSize: 12, color: kTextMuted)),
    ]),
  );

  Widget _noSleepNote() => _panel(child: const Row(children: [
    Icon(Icons.bedtime_outlined, size: 20, color: kTextSecondary),
    SizedBox(width: 12),
    Expanded(child: Text(
        'No sleep data logged yet — log bed and wake times to see sleep stats here.',
        style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4))),
  ]));

  // ── Today Tab ─────────────────────────────────────────────────────────────

  Widget _todayTab() {
    // train/skill/total are built on the same day grid, so one emptiness check
    // covers all three.
    if (_m.total.isEmpty) {
      return _emptyState(
        icon: Icons.local_fire_department_outlined,
        title: 'No data for today yet',
        hint: "Log a session or wellness check-in to see today's summary here.",
      );
    }
    final train = _m.train.last;
    final skill = _m.skill.last;
    final total = _m.total.last;
    final well  = _m.recovery.isEmpty ? null : _m.recovery.last;
    final readyCol = well == null
        ? kTextMuted
        : well.readinessPct >= 0.6 ? kAccent
        : well.readinessPct >= 0.35 ? kWarn
        : kDanger;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kGutter, 16, kGutter, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Date header
        const Text("Today's summary", style: _kLabel),
        const SizedBox(height: 2),
        Semantics(
          header: true,
          child: Text(_fmtLongDate(total.date),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.4)),
        ),
        const SizedBox(height: 16),

        // Exertion arc trio
        Row(children: [
          Expanded(child: _exertionArc('Training', train.exertion, kSky)),
          const SizedBox(width: 10),
          Expanded(child: _exertionArc('Skill',    skill.exertion, kSuccess)),
          const SizedBox(width: 10),
          Expanded(child: _exertionArc('Total',    total.exertion, kViolet)),
        ]),
        const SizedBox(height: 12),

        // Session cards
        _sessionCard('Training',    train, kSky),
        const SizedBox(height: 10),
        _sessionCard('Skill',       skill, kSuccess),
        const SizedBox(height: 10),
        _sessionCard('Daily total', total, kViolet),
        const SizedBox(height: 12),

        // Readiness today
        well == null
            ? _panel(child: const Row(children: [
                Icon(Icons.favorite_outline_rounded, size: 20, color: kTextSecondary),
                SizedBox(width: 12),
                Expanded(child: Text(
                    'No wellness check-in yet — complete one to see readiness here.',
                    style: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4))),
              ]))
            : _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _cardTitle("Today's readiness")),
                  _dot(readyCol),
                  const SizedBox(width: 6),
                  Text('${(well.readinessPct * 100).round()}%',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary,
                          letterSpacing: -0.3, fontFeatures: _kTabular)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _readyBadge('Sleep',    well.sleep)),
                  Expanded(child: _readyBadge('Wellness', well.wellness)),
                  Expanded(child: _readyBadge('Soreness', well.soreness)),
                  Expanded(child: _readyBadge('Fatigue',  well.fatigue)),
                ]),
              ])),
      ]),
    );
  }

  Widget _exertionArc(String label, double exertion, Color color) {
    return Semantics(
      label: '$label exertion ${exertion.toStringAsFixed(1)} out of 10',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(color: kBorder, width: 0.6),
        ),
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(
              painter: _ExertionArcPainter(exertion: exertion, color: color),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: _kLabel),
        ]),
      ),
    );
  }

  Widget _sessionCard(String title, _WP pt, Color color) {
    final zColor = _acwrColor(pt.acwr);
    return _panel(child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _seriesTitle(title, color),
        const SizedBox(height: 8),
        Row(children: [
          _miniStat('Load',     pt.load > 0 ? pt.load.toStringAsFixed(0) : '—'),
          const SizedBox(width: 16),
          _miniStat('Exertion', pt.exertion.toStringAsFixed(1)),
        ]),
      ])),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text.rich(TextSpan(children: [
          TextSpan(
            text: pt.acwr.toStringAsFixed(2),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary,
                letterSpacing: -0.6, fontFeatures: _kTabular),
          ),
          const TextSpan(text: ' ACWR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary)),
        ])),
        const SizedBox(height: 4),
        _StatusDot(color: zColor, label: _acwrZone(pt.acwr)),
      ]),
    ]));
  }

  // ── Shared Widgets ─────────────────────────────────────────────────────────

  // Tab-level empty state: plain icon, title, one line of guidance.
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: kTextMuted),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 6),
            Text(hint, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // Read-only identity chip — shows the signed-in athlete, not a switcher.
  Widget _athleteToggle() {
    return Semantics(
      label: 'Signed in as $_athleteLabel',
      excludeSemantics: true,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kBorder, width: 0.6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline_rounded, size: 15, color: kTextSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              _athleteLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
            ),
          ),
        ]),
      ),
    );
  }

  /// Segmented control for the 7 / 14 / 28-day window.
  Widget _rangeBar() {
    const keys   = ['7d', '14d', '28d'];
    const labels = ['7 days', '14 days', '28 days'];
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusSm),
        border: Border.all(color: kBorder, width: 0.6),
      ),
      child: Row(children: List.generate(3, (i) {
        final active = _range == keys[i];
        return Expanded(child: Semantics(
          button: true,
          selected: active,
          label: labels[i],
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () {
                if (!active) hapticSelect();
                setState(() => _range = keys[i]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? kBorderBright : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? kTextPrimary : kTextSecondary,
                    )),
              ),
            ),
          ),
        ));
      })),
    );
  }

  /// Label over value, used under the ACWR sparklines.
  Widget _statPill(String label, String value) => MergeSemantics(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _kLabel),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary,
          letterSpacing: -0.3, fontFeatures: _kTabular)),
    ]),
  );

  Widget _miniStat(String label, String value) => Text.rich(TextSpan(children: [
    TextSpan(text: '$label ', style: const TextStyle(fontSize: 13, color: kTextSecondary)),
    TextSpan(text: value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary,
        fontFeatures: _kTabular)),
  ]));

  Widget _microBadge(String label, int value) {
    final col = value <= 2 ? kAccent : value == 3 ? kWarn : kDanger;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _dot(col, size: 6),
      const SizedBox(width: 5),
      Text('$label $value', style: const TextStyle(fontSize: 12, color: kTextSecondary)),
    ]);
  }

  Widget _readyBadge(String label, int value) {
    final col = value <= 2 ? kAccent : value == 3 ? kWarn : kDanger;
    return MergeSemantics(
      child: Column(children: [
        Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary,
            letterSpacing: -0.4)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(col, size: 6),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        ]),
      ]),
    );
  }

  Widget _ldot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    _dot(color),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
  ]);

  Widget _dot(Color color, {double size = 7}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  /// Card title (17 w600).
  Widget _cardTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2),
  );

  /// Card title keyed to its chart series by a small colour dot.
  Widget _seriesTitle(String title, Color color) => Row(children: [
    _dot(color, size: 8),
    const SizedBox(width: 8),
    Flexible(child: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2),
    )),
  ]);

  /// Flat card with a hairline edge; tappable (with ripple + haptic) when
  /// [onTap] is given.
  Widget _panel({required Widget child, VoidCallback? onTap}) => Material(
    color: kCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kRadius),
      side: const BorderSide(color: kBorder, width: 0.6),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap == null ? null : () { hapticSelect(); onTap(); },
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtLongDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  Color _acwrColor(double v) {
    if (v < 0.8)  return kInfo;
    if (v <= 1.3) return kSuccess;
    if (v <= 1.5) return kWarn;
    return kDanger;
  }

  String _acwrZone(double v) {
    if (v < 0.8)  return 'Undertraining';
    if (v <= 1.3) return 'Sweet spot';
    if (v <= 1.5) return 'Caution';
    return 'Danger zone';
  }

  String _readinessLabel(double pct) {
    if (pct >= 0.70) return 'Peak ready';
    if (pct >= 0.50) return 'Good';
    if (pct >= 0.35) return 'Moderate';
    return 'Low';
  }

  String _ratingLabel(int v) {
    const labels = {1: 'Excellent', 2: 'Good', 3: 'Moderate', 4: 'Poor', 5: 'Very poor'};
    return labels[v] ?? 'Very poor';
  }
}

// ── Shared styles & widgets ───────────────────────────────────────────────────

/// Large figure (28 w700, tightened).
const TextStyle _kHeroValue = TextStyle(
  fontSize: 28, fontWeight: FontWeight.w700, color: kTextPrimary,
  letterSpacing: -0.8, height: 1.1, fontFeatures: _kTabular,
);

/// Small unit beside a large figure.
const TextStyle _kUnit = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary);

/// Caption / field label.
const TextStyle _kLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary);

/// Chart axis / tick text.
const TextStyle _kAxis = TextStyle(color: kTextMuted, fontSize: 11);

/// Tabular figures so numbers line up.
const List<FontFeature> _kTabular = [FontFeature.tabularFigures()];

/// Status = a dot in the status colour + the word in neutral text.
class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;

  /// Let the label shrink (ellipsis) — only when placed in a bounded slot.
  final bool flexible;
  const _StatusDot({required this.color, required this.label, this.flexible = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        flexible ? Flexible(child: text) : text,
      ],
    );
  }
}

TextPainter _layoutText(String s, TextStyle style) =>
    TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();

/// Hairline horizontal gridline.
final Paint _kGridPaint = Paint()..color = kBorder..strokeWidth = 0.6;

/// Draws a horizontal-ish dashed line from [a] to [b] — used for threshold
/// gridlines so they read as reference marks rather than data.
void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 4.0, gap = 3.0;
  final total = (b - a).distance;
  final dir = (b - a) / total;
  var covered = 0.0;
  while (covered < total) {
    final segEnd = min(covered + dash, total);
    canvas.drawLine(a + dir * covered, a + dir * segEnd, paint);
    covered += dash + gap;
  }
}

// ── Smooth-line helper ───────────────────────────────────────────────────────

/// Catmull-Rom → cubic Bézier smoothing: an open path threading every point in
/// [pts] with soft curves instead of straight segments. Needs at least 2 points.
Path _smoothLinePath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (int i = 0; i < pts.length - 1; i++) {
    final p0 = i > 0 ? pts[i - 1] : pts[0];
    final p1 = pts[i], p2 = pts[i + 1];
    final p3 = i < pts.length - 2 ? pts[i + 2] : pts[pts.length - 1];
    final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
    final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
  }
  return path;
}

// ── Load vs Exertion Painter (smooth line = load, smooth line = exertion 0–10) ─

class _LoadExertionPainter extends CustomPainter {
  final List<_WP> data;
  final Color barColor;
  _LoadExertionPainter({required this.data, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final n = data.length;
    const bPad = 20.0, tPad = 12.0;
    final chartH = size.height - bPad - tPad;
    final slotW = size.width / n;
    double xAt(int i) => i * slotW + slotW / 2;
    final maxLoad = data.fold(0.0, (p, w) => w.load > p ? w.load : p).clamp(1.0, 1e9);

    // Hairline grid: top, middle, baseline
    for (final f in [0.0, 0.5, 1.0]) {
      final y = tPad + chartH * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _kGridPaint);
    }

    double loadY(double v)  => tPad + chartH * (1 - (v / maxLoad).clamp(0, 1) * 0.82);
    double exertY(double v) => tPad + chartH * (1 - v.clamp(0, 10) / 10.0);
    final loadPts  = List.generate(n, (i) => Offset(xAt(i), loadY(data[i].load)));
    final exertPts = List.generate(n, (i) => Offset(xAt(i), exertY(data[i].exertion)));

    // Smooth line + flat wash = load
    if (n >= 2) {
      final line = _smoothLinePath(loadPts);
      final fill = Path.from(line)
        ..lineTo(loadPts.last.dx, size.height - bPad)
        ..lineTo(loadPts.first.dx, size.height - bPad)
        ..close();
      canvas.drawPath(fill, Paint()..color = barColor.withValues(alpha: 0.10));
      canvas.drawPath(
        line,
        Paint()
          ..color = barColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final p in loadPts) {
      canvas.drawCircle(p, 2.0, Paint()..color = barColor);
    }

    // Smooth line = exertion on a fixed 0–10 scale
    if (n >= 2) {
      canvas.drawPath(
        _smoothLinePath(exertPts),
        Paint()
          ..color = Colors.pinkAccent
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final p in exertPts) {
      canvas.drawCircle(p, 2.0, Paint()..color = Colors.pinkAccent);
    }

    // Date labels
    final step = (n / 5).ceil().clamp(1, n);
    for (int i = 0; i < n; i += step) {
      final tp = _layoutText(data[i].d.split('/')[0], _kAxis);
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, size.height - bPad + 5));
    }
  }

  @override
  bool shouldRepaint(_LoadExertionPainter old) =>
      old.data != data || old.barColor != barColor;
}

// ── ACWR Sparkline Painter ────────────────────────────────────────────────────

class _AcwrSparkPainter extends CustomPainter {
  final List<_WP> data;
  final Color color;
  const _AcwrSparkPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final n = data.length;
    final h = size.height, w = size.width;
    const vMin = 0.0, vMax = 2.0;
    double yAt(double v) => h - (h - 6) * ((v - vMin) / (vMax - vMin)) - 3;
    double xAt(int i) => i * w / (n - 1);

    // Zone bands — a faint flat wash per zone
    void band(double lo, double hi, Color c) =>
        canvas.drawRect(Rect.fromLTRB(0, yAt(hi), w, yAt(lo)), Paint()..color = c);
    band(1.5, 2.0, kDanger.withValues(alpha: 0.06));
    band(1.3, 1.5, kWarn.withValues(alpha: 0.06));
    band(0.8, 1.3, kSuccess.withValues(alpha: 0.06));
    band(0.0, 0.8, kInfo.withValues(alpha: 0.05));

    // Threshold lines — dashed, colour-matched to the zone they bound.
    const thresholds = [(0.8, kInfo), (1.3, kWarn), (1.5, kDanger)];
    for (final (v, c) in thresholds) {
      _drawDashedLine(canvas, Offset(0, yAt(v)), Offset(w, yAt(v)),
          Paint()..color = c.withValues(alpha: 0.5)..strokeWidth = 0.8);
    }

    final vals = data.map((p) => p.acwr.clamp(vMin, vMax)).toList();
    final pts  = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));

    // Line + flat wash
    final line = _smoothLinePath(pts);
    final fill = Path.from(line)..lineTo(pts.last.dx, h)..lineTo(pts.first.dx, h)..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(line, Paint()
      ..color = color..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Value tags for all three boundaries. Alternating left/right keeps 1.3
    // and 1.5 (close together) from overlapping. Drawn last, each on an
    // opaque chip, so they stay legible over the bands and the curve.
    for (final (i, (v, _)) in thresholds.indexed) {
      final onLeft = i.isEven;
      final tp = _layoutText(v.toStringAsFixed(1), _kAxis);
      final boxW = tp.width + 6;
      final top = (yAt(v) - tp.height / 2).clamp(0.0, h - tp.height);
      final left = onLeft ? 2.0 : w - boxW - 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, boxW, tp.height), const Radius.circular(3)),
        Paint()..color = kCard.withValues(alpha: 0.94),
      );
      tp.paint(canvas, Offset(left + 3, top));
    }

    // Last point, ringed in the card colour so it reads over the line.
    canvas.drawCircle(pts.last, 5.5, Paint()..color = kCard);
    canvas.drawCircle(pts.last, 4.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AcwrSparkPainter old) => old.data != data || old.color != color;
}

// ── Metric Bars Painter ───────────────────────────────────────────────────────

/// Height a score of 1 draws at, as a fraction of the tallest bar.
const double _kMinBar = 0.12;

class _MetricBarsPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color color;
  const _MetricBarsPainter({required this.values, required this.labels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final slotW = size.width / n;
    // Room above the bars for the value labels and below for the day labels.
    const topPad = 16.0, bottomPad = 20.0;
    final maxBarH = size.height - topPad - bottomPad;
    final baseY   = topPad + maxBarH;

    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), _kGridPaint);

    for (int i = 0; i < n; i++) {
      final isLast  = i == n - 1;
      // Bar length tracks the raw 1–5 score, so 5 draws longest and 1 shortest.
      // Height therefore reads as severity, not quality — on these metrics a
      // taller bar is a worse day.
      //
      // The scale is stretched to 0.12–1.0 rather than the natural v/5 (0.2–1.0)
      // so the mid-range scores that dominate real logs separate a little more.
      // It stays a fixed mapping, not a per-panel normalisation, so bar heights
      // remain comparable across metrics and athletes.
      final severity = _kMinBar +
          (values[i].clamp(1, 5) - 1) / 4.0 * (1.0 - _kMinBar);
      final barH    = maxBarH * severity;
      // Narrow bars: at 0.62 of the slot they came out wider than they were
      // tall, so height differences read as noise next to the block of colour.
      final barW    = slotW * 0.36;
      final x       = i * slotW + (slotW - barW) / 2;
      final y       = baseY - barH;

      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, y, barW, barH),
            topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: isLast ? 1.0 : 0.40),
      );

      // Value above bar
      final tv = _layoutText('${values[i]}', TextStyle(
        color: isLast ? kTextPrimary : kTextMuted,
        fontSize: 11,
        fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
      ));
      tv.paint(canvas, Offset(i * slotW + slotW / 2 - tv.width / 2, max(0, y - 3 - tv.height)));

      // Day label
      final td = _layoutText(labels[i].split('/')[0], _kAxis);
      td.paint(canvas, Offset(i * slotW + slotW / 2 - td.width / 2, baseY + 5));
    }
  }

  @override
  bool shouldRepaint(_MetricBarsPainter old) => old.values != values || old.color != color;
}

// ── Exertion Arc Painter ──────────────────────────────────────────────────────

class _ExertionArcPainter extends CustomPainter {
  final double exertion;
  final Color  color;
  const _ExertionArcPainter({required this.exertion, required this.color});

  static const double _startDeg = 135.0;
  static const double _sweepDeg = 270.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center   = Offset(size.width / 2, size.height / 2);
    final radius   = size.width / 2 - 6;
    final startRad = _startDeg * pi / 180;
    final sweepRad = _sweepDeg * pi / 180;
    const strokeW  = 7.0;
    final arcRect  = Rect.fromCircle(center: center, radius: radius - strokeW / 2);

    // Track
    canvas.drawArc(arcRect, startRad, sweepRad, false, Paint()
      ..color = kBorderBright
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Progress (exertion maps 2→0%, 10→100%)
    final pct = ((exertion - 2.0) / 8.0).clamp(0.0, 1.0);
    if (pct > 0) {
      canvas.drawArc(arcRect, startRad, sweepRad * pct, false, Paint()
        ..color = color..strokeWidth = strokeW
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }

    // Value
    final fs = size.width * 0.22;
    final tp = _layoutText(exertion.toStringAsFixed(1),
        TextStyle(color: kTextPrimary, fontSize: fs, fontWeight: FontWeight.w700, letterSpacing: -0.6));
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 3));

    // "/10"
    final tp2 = _layoutText('/10',
        TextStyle(color: kTextSecondary, fontSize: max(11.0, fs * 0.5), fontWeight: FontWeight.w500));
    tp2.paint(canvas, center - Offset(tp2.width / 2, tp.height / 2 + 3 - fs * 0.95));
  }

  @override
  bool shouldRepaint(_ExertionArcPainter old) => old.exertion != exertion || old.color != color;
}

// ── Cumulative Score Painter ──────────────────────────────────────────────────

class _CumulativeScorePainter extends CustomPainter {
  final List<int> totals;
  final List<String> dates;
  const _CumulativeScorePainter({required this.totals, required this.dates});

  @override
  void paint(Canvas canvas, Size size) {
    if (totals.length < 2) return;
    final n = totals.length;
    const bPad = 20.0, tPad = 6.0, lPad = 24.0;
    final chartH = size.height - bPad - tPad;
    final chartW = size.width - lPad;
    const vMin = 4.0, vMax = 20.0;

    double yAt(double v) => tPad + chartH * (1 - (v - vMin) / (vMax - vMin));
    double xAt(int i) => lPad + chartW * i / (n - 1);

    // Zone bands — a faint flat wash per zone
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(8), size.width, yAt(4)),
        Paint()..color = kSuccess.withValues(alpha: 0.05));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(13), size.width, yAt(8)),
        Paint()..color = kWarn.withValues(alpha: 0.05));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(20), size.width, yAt(13)),
        Paint()..color = kDanger.withValues(alpha: 0.05));

    // Baseline
    canvas.drawLine(Offset(lPad, yAt(vMin)), Offset(size.width, yAt(vMin)), _kGridPaint);

    // Reference lines at 8 and 13 (PDF requirement), labelled on the axis
    for (final (v, c) in [(8.0, kSuccess), (13.0, kDanger)]) {
      final y = yAt(v);
      _drawDashedLine(canvas, Offset(lPad, y), Offset(size.width, y),
          Paint()..color = c.withValues(alpha: 0.5)..strokeWidth = 0.8);
      final tp = _layoutText(v.toStringAsFixed(0), _kAxis);
      tp.paint(canvas, Offset(lPad - 6 - tp.width, y - tp.height / 2));
    }

    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(totals[i].toDouble())));

    // Smooth line
    canvas.drawPath(_smoothLinePath(pts), Paint()
      ..color = kViolet..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Dots, coloured by zone; the latest one larger, ringed in the card colour
    for (int i = 0; i < n; i++) {
      final v = totals[i];
      final c = v <= 8 ? kAccent : v <= 13 ? kWarn : kDanger;
      if (i == n - 1) canvas.drawCircle(pts[i], 5.5, Paint()..color = kCard);
      canvas.drawCircle(pts[i], i == n - 1 ? 4.0 : 2.6, Paint()..color = c);
    }

    // Date labels
    final step = max(1, n ~/ 5);
    for (int i = 0; i < n; i += step) {
      final tp = _layoutText(dates[i].split('/')[0], _kAxis);
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, size.height - bPad + 5));
    }
  }

  @override
  bool shouldRepaint(_CumulativeScorePainter old) => old.totals != totals;
}

// ── Readiness Ring Painter ────────────────────────────────────────────────────

class _ReadinessRingPainter extends CustomPainter {
  final double pct;
  final Color  color;
  const _ReadinessRingPainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center  = size.center(Offset.zero);
    const strokeW = 7.0;
    final radius  = size.width / 2 - strokeW / 2 - 2;

    canvas.drawCircle(center, radius, Paint()
      ..color = kBorderBright
      ..style = PaintingStyle.stroke..strokeWidth = strokeW);

    if (pct > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * pct.clamp(0.0, 1.0), false,
        Paint()
          ..color = color..strokeWidth = strokeW
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ReadinessRingPainter old) => old.pct != pct || old.color != color;
}
