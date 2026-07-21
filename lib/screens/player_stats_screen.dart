import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../api_service.dart';
import '../services/dashboard_metrics.dart';
import '../services/sleep_metrics.dart';
import 'workload_monitor_screen.dart';

// ── Data Models & series ────────────────────────────────────────────────────────
// The workload / recovery models and athlete series live in dashboard_metrics.dart
// (single source of truth shared with the home dashboard rings). Aliased here so
// this screen's existing references stay unchanged.

typedef _WP = WorkPoint;
typedef _RP = RecoveryPoint;

// Athlete series (single source of truth in dashboard_metrics.dart).
const _a1Train = kA1Train;
const _a1Skill = kA1Skill;
const _a1Total = kA1Total;
const _a2Train = kA2Train;
const _a2Skill = kA2Skill;
const _a2Total = kA2Total;
const _well1   = kWell1;
const _well2   = kWell2;

// ── Sleep Detail History ──────────────────────────────────────────────────────
// Logged clock times per night. Sleep time, efficiency, 7-day average and debt
// are all derived from these by the sheet formulae in sleep_metrics.dart rather
// than stored, so the dashboard can never disagree with the spreadsheet.
// Columns: bed → fell asleep → woke → out of bed, plus minutes awake after a
// disturbance.

SleepNight _n(String d, int bedH, int bedM, int lat, int wakeH, int wakeM,
        {int outH = -1, int outM = 0, int awake = 0}) =>
    nightFromLog(
      d: d,
      timeToBed: hm(bedH, bedM),
      latencyMinutes: lat,
      wokeUp: hm(wakeH, wakeM),
      outOfBed: outH < 0 ? null : hm(outH, outM),
      awakeMinutes: awake,
    );

final _sleep1 = <SleepNight>[
  _n('24/04', 22, 20, 20, 6, 32, awake: 28),
  _n('25/04', 22, 50, 15, 6, 20, awake: 21),
  _n('26/04', 22, 30, 25, 6, 30, awake: 35),
  _n('27/04', 22,  5, 20, 6, 35, awake: 22),
  _n('28/04', 23, 15, 20, 6, 27, awake: 34),
  _n('29/04', 22, 15, 15, 6, 33, awake: 27),
  _n('30/04', 22,  0, 15, 6, 36, awake: 21),
  _n('01/05', 23, 30, 20, 6, 30, awake: 34),
  _n('02/05', 22, 45, 25, 6, 33, awake: 35),
  _n('03/05', 23, 10, 20, 6, 28, awake: 34),
  _n('04/05', 22, 10, 15, 6, 34, awake: 15),
  _n('05/05', 22,  0, 15, 6, 30, awake: 15),
  _n('06/05', 23, 25, 20, 6, 31, awake: 34),
  _n('07/05', 22, 20, 15, 6, 32, awake: 27),
];
final _sleep2 = <SleepNight>[
  _n('24/04', 23, 10, 25, 6, 10, awake: 41),
  _n('25/04', 22, 40, 20, 6, 28, awake: 34),
  _n('26/04', 23, 50, 30, 6, 38, awake: 42),
  _n('27/04', 22, 20, 20, 6, 26, awake: 22),
  _n('28/04', 23, 20, 25, 6, 32, awake: 41),
  _n('29/04', 22, 30, 20, 6, 30, awake: 28),
  _n('30/04', 22, 15, 15, 6, 33, awake: 27),
  _n('01/05', 23, 55, 30, 6, 49, awake: 42),
  _n('02/05', 23,  5, 20, 6, 29, awake: 34),
  _n('03/05', 22,  0, 15, 6, 30, awake: 15),
  _n('04/05', 21, 55, 15, 6, 31, awake: 15),
  _n('05/05', 22, 50, 20, 6, 26, awake: 34),
  _n('06/05', 23, 15, 25, 6, 15, awake: 41),
  _n('07/05', 22,  5, 15, 6, 29, awake: 21),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class PlayerStatsScreen extends StatefulWidget {
  /// Which tab to open first: 0 = Performance, 1 = Recovery, 2 = Today.
  final int initialTab;
  const PlayerStatsScreen({super.key, this.initialTab = 0});

  @override
  State<PlayerStatsScreen> createState() => _PDS();
}

class _PDS extends State<PlayerStatsScreen> with SingleTickerProviderStateMixin {
  int    _athlete = 0;
  String _athleteLabel = 'ATS-2025-001';
  String _range   = '28d';
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    // Bind the dashboard to the logged-in athlete so a player only ever sees
    // their own data — no cross-athlete switching.
    ApiService.getCachedUser().then((u) {
      if (u == null || !mounted) return;
      setState(() {
        _athlete      = u.name.contains('002') ? 1 : 0;
        _athleteLabel = u.name;
      });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<_WP> _filter(List<_WP> all) {
    final n = _range == '7d' ? 7 : _range == '14d' ? 14 : all.length;
    return all.sublist(max(0, all.length - n));
  }

  List<_WP> get _trainData => _filter(_athlete == 0 ? _a1Train : _a2Train);
  List<_WP> get _skillData => _filter(_athlete == 0 ? _a1Skill : _a2Skill);
  List<_WP> get _totalData => _filter(_athlete == 0 ? _a1Total : _a2Total);
  List<_RP> get _wellData  => _athlete == 0 ? _well1 : _well2;
  List<SleepNight> get _sleepData => _athlete == 0 ? _sleep1 : _sleep2;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text(
          'DASHBOARD',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            Divider(height: 1, color: kBorder),
            TabBar(
              controller: _tabs,
              labelColor: kAccent,
              unselectedLabelColor: kTextSecondary,
              indicatorColor: kAccent,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.show_chart_rounded, size: 15),               text: 'Performance'),
                Tab(icon: Icon(Icons.favorite_rounded, size: 15),                 text: 'Recovery'),
                Tab(icon: Icon(Icons.local_fire_department_rounded, size: 15),    text: 'Today'),
              ],
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_performanceTab(), _recoveryTab(), _todayTab()],
      ),
    );
  }

  // ── Performance Tab ────────────────────────────────────────────────────────

  Widget _performanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _athleteToggle(),
          const SizedBox(height: 12),
          _rangeBar(),
          const SizedBox(height: 16),
          _acwrPanel('Training Workload', _trainData, kSky),
          const SizedBox(height: 12),
          _acwrPanel('Skill Workload',    _skillData, kSuccess),
          const SizedBox(height: 12),
          _acwrPanel('Daily Total',       _totalData, kViolet),
          const SizedBox(height: 18),

          Text('LOAD VS EXERTION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: kTextSecondary, letterSpacing: 1.4)),
          const SizedBox(height: 10),
          _loadExertionPanel('Training Load vs Exertion', _trainData, kSky),
          const SizedBox(height: 12),
          _loadExertionPanel('Skill Load vs Exertion',    _skillData, kSuccess),
          const SizedBox(height: 12),
          _loadExertionPanel('Daily Load vs Exertion',    _totalData, kViolet),
        ],
      ),
    );
  }

  Widget _loadExertionPanel(String title, List<_WP> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ]),
      const SizedBox(height: 4),
      Text('Bars = Load  ·  Pink line = Exertion',
          style: TextStyle(fontSize: 10, color: kTextSecondary)),
      const SizedBox(height: 10),
      SizedBox(
        height: 124,
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
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const WorkloadMonitorScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: zColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: zColor.withValues(alpha: 0.35)),
              ),
              child: Text('ACWR ${last.acwr.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zColor)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: kTextMuted),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _AcwrSparkPainter(data: data, color: color),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _statPill('Load', last.load > 0 ? last.load.toStringAsFixed(0) : '—', color),
            const SizedBox(width: 8),
            _statPill('Exertion', last.exertion.toStringAsFixed(1), Colors.pinkAccent),
            const SizedBox(width: 8),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: zColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: zColor.withValues(alpha: 0.28)),
              ),
              child: Text(zLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zColor)),
            )),
          ]),
        ]),
      ),
    );
  }

  // ── Recovery Tab ──────────────────────────────────────────────────────────

  Widget _recoveryTab() {
    final well   = _wellData;
    final last7  = well.sublist(max(0, well.length - 7));
    final avgPct = last7.map((r) => r.readinessPct).reduce((a, b) => a + b) / last7.length;
    final todayR = well.last.readinessPct;
    final rColor = todayR >= 0.60 ? kAccent : todayR >= 0.35 ? kWarn : kDanger;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _athleteToggle(),
        const SizedBox(height: 14),

        // Readiness score card
        _panel(child: Row(children: [
          SizedBox(
            width: 88, height: 88,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                painter: _ReadinessRingPainter(pct: avgPct, color: rColor),
                size: const Size(88, 88),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(avgPct * 100).round()}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: rColor, letterSpacing: -1)),
                Text('%', style: TextStyle(fontSize: 9, color: rColor.withValues(alpha: 0.7))),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('READINESS SCORE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            Text(_readinessLabel(avgPct),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: rColor, letterSpacing: -0.3)),
            const SizedBox(height: 3),
            Text('7-day avg  ·  Today ${(todayR * 100).round()}%',
                style: TextStyle(fontSize: 11, color: kTextSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _microBadge('Sleep',    well.last.sleep),
              _microBadge('Wellness', well.last.wellness),
              _microBadge('Soreness', well.last.soreness),
              _microBadge('Fatigue',  well.last.fatigue),
            ]),
          ])),
        ])),
        const SizedBox(height: 14),

        // Cumulative recovery score (PDF: total of 4 metrics, lines at 8 & 13)
        _cumulativeScorePanel(well),
        const SizedBox(height: 14),

        // Sleep summary (efficiency, debt, overall summary)
        _sleepSummaryPanel(_sleepData),
        const SizedBox(height: 14),

        _metricBars('Sleep Quality',    well.map((r) => r.sleep).toList(),    kSleep,              well.map((r) => r.d).toList()),
        const SizedBox(height: 10),
        _metricBars('Wellness',         well.map((r) => r.wellness).toList(), kAccent,             well.map((r) => r.d).toList()),
        const SizedBox(height: 10),
        _metricBars('Muscle Soreness',  well.map((r) => r.soreness).toList(), kWarn, well.map((r) => r.d).toList()),
        const SizedBox(height: 10),
        _metricBars('Fatigue',          well.map((r) => r.fatigue).toList(),  kDanger,    well.map((r) => r.d).toList()),
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
        Container(width: 3, height: 14, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text('$cur — ${_ratingLabel(cur)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
        ),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        // Tall enough that one point of score is worth ~15px of bar. At the
        // previous 68 it was ~10px, which read as noise against the bar width.
        height: 100,
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
    final zone   = cur <= 8 ? 'Optimal Recovery' : cur <= 13 ? 'Monitor — Moderate Load' : 'High Exertion — Intervene';
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.stacked_line_chart_rounded, size: 14, color: kTextSecondary),
        const SizedBox(width: 6),
        Text('Cumulative Recovery Score',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: col.withValues(alpha: 0.35)),
          ),
          child: Text('$cur / 20',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Total of Sleep + Wellness + Soreness + Fatigue · $zone',
          style: TextStyle(fontSize: 10, color: col)),
      const SizedBox(height: 12),
      SizedBox(
        height: 150,
        child: CustomPaint(
          painter: _CumulativeScorePainter(totals: totals, dates: well.map((r) => r.d).toList()),
          size: Size.infinite,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        _ldot(kAccent,             '≤ 8  Optimal'),
        _ldot(kWarn, '8–13  Caution'),
        _ldot(kDanger,    '> 13  Risk'),
      ]),
    ]));
  }

  // ── Sleep Summary Panel ─────────────────────────────────────────────────────

  Widget _sleepSummaryPanel(List<SleepNight> sleep) {
    // All four headline figures come straight from the sheet formulae:
    // sleep time (1), 7-day average (3), efficiency (5) and sleep debt (6).
    final i       = sleep.length - 1;
    final last    = sleep[i];
    final avgMins = averageSleepMinutes(sleep, i);
    final debt    = sleepDebtMinutes(sleep, i);      // null = no debt that night
    final effPct  = last.efficiency * 100;

    final effCol  = effPct >= 85 ? kAccent : effPct >= 75 ? kWarn : kDanger;
    // Debt is measured against the athlete's own weekly average, so an hour
    // behind is already meaningful — much tighter thresholds than a fixed need.
    final debtCol = debt == null || debt <= 30
        ? kAccent
        : debt <= 60 ? kWarn : kDanger;

    final summary = effPct >= 85 && (debt ?? 0) <= 30
        ? 'Sleep is restorative — efficiency is high and last night held the weekly average. Maintain current routine.'
        : (debt ?? 0) > 60
            ? 'Last night fell more than an hour below the 7-day average. Prioritise an earlier bedtime tonight and a recovery nap.'
            : 'Sleep is adequate but inconsistent. Aim for steadier bedtimes to lift efficiency and clear debt.';

    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.bedtime_rounded, size: 14, color: kSleep),
        const SizedBox(width: 6),
        Text('Sleep Summary',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const Spacer(),
        Text('In bed ${formatHhMm(last.timeInBedMinutes)}',
            style: TextStyle(fontSize: 10, color: kTextSecondary)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _sleepStat('Sleep Time', formatHhMm(last.sleepMinutes), 'last night', kSleep)),
        const SizedBox(width: 10),
        Expanded(child: _sleepStat('7-Day Average', formatHhMm(avgMins), 'rolling', kSleep)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _sleepStat('Efficiency', '${effPct.toStringAsFixed(0)}%', 'asleep / in bed', effCol)),
        const SizedBox(width: 10),
        Expanded(child: _sleepStat(
          'Sleep Debt',
          debt == null ? '—' : formatHhMm(debt),
          debt == null ? 'at or above avg' : 'vs 7-day avg',
          debtCol,
        )),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSleep.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kSleep.withValues(alpha: 0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline_rounded, size: 14, color: kSleep),
          const SizedBox(width: 8),
          Expanded(child: Text(summary,
              style: TextStyle(fontSize: 11.5, color: kTextSecondary, height: 1.4))),
        ]),
      ),
    ]));
  }

  Widget _sleepStat(String label, String value, String sub, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kTextPrimary)),
      Text(sub, style: TextStyle(fontSize: 9, color: kTextSecondary)),
    ]),
  );

  // ── Today Tab ─────────────────────────────────────────────────────────────

  Widget _todayTab() {
    final trainAll = _athlete == 0 ? _a1Train : _a2Train;
    final skillAll = _athlete == 0 ? _a1Skill : _a2Skill;
    final totalAll = _athlete == 0 ? _a1Total : _a2Total;
    final train = trainAll.last;
    final skill = skillAll.last;
    final total = totalAll.last;
    final well  = _wellData.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _athleteToggle(),
        const SizedBox(height: 14),

        // Date header
        _panel(child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 15, color: kTextSecondary),
          const SizedBox(width: 8),
          Text('07 May 2025',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
            child: Text("TODAY'S SUMMARY",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kAccent, letterSpacing: 0.8)),
          ),
        ])),
        const SizedBox(height: 14),

        // Exertion arc trio
        Row(children: [
          Expanded(child: _exertionArc('Training', train.exertion, kSky)),
          const SizedBox(width: 10),
          Expanded(child: _exertionArc('Skill',    skill.exertion, kSuccess)),
          const SizedBox(width: 10),
          Expanded(child: _exertionArc('Total',    total.exertion, kViolet)),
        ]),
        const SizedBox(height: 14),

        // Session cards
        _sessionCard('Training',    train, kSky, Icons.fitness_center_rounded),
        const SizedBox(height: 10),
        _sessionCard('Skill',       skill, kSuccess,     Icons.sports_cricket_rounded),
        const SizedBox(height: 10),
        _sessionCard('Daily Total', total, kViolet,    Icons.stacked_bar_chart_rounded),
        const SizedBox(height: 14),

        // Readiness today
        _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.favorite_rounded, size: 14, color: kTextSecondary),
            const SizedBox(width: 6),
            Text("Today's Readiness",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const Spacer(),
            () {
              final col = well.readinessPct >= 0.6 ? kAccent
                  : well.readinessPct >= 0.35 ? kWarn
                  : kDanger;
              return Text('${(well.readinessPct * 100).round()}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col));
            }(),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _readyBadge('Sleep',    well.sleep),
            _readyBadge('Wellness', well.wellness),
            _readyBadge('Soreness', well.soreness),
            _readyBadge('Fatigue',  well.fatigue),
          ]),
        ])),
      ]),
    );
  }

  Widget _exertionArc(String label, double exertion, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: _ExertionArcPainter(exertion: exertion, color: color),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 6),
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.0)),
      ]),
    );
  }

  Widget _sessionCard(String title, _WP pt, Color color, IconData icon) {
    final zColor = _acwrColor(pt.acwr);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 5),
          Row(children: [
            _miniStat('Load',     pt.load > 0 ? pt.load.toStringAsFixed(0) : '—', color),
            const SizedBox(width: 16),
            _miniStat('Exertion', pt.exertion.toStringAsFixed(1), Colors.pinkAccent),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(pt.acwr.toStringAsFixed(2),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: zColor, letterSpacing: -0.5)),
          Text('ACWR', style: TextStyle(fontSize: 9, color: kTextSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(_acwrZone(pt.acwr),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: zColor)),
        ]),
      ]),
    );
  }

  // ── Shared Widgets ─────────────────────────────────────────────────────────

  // Read-only identity chip — shows the signed-in athlete, not a switcher.
  Widget _athleteToggle() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_rounded, size: 14, color: kAccent),
        const SizedBox(width: 6),
        Text(_athleteLabel,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kAccent)),
      ]),
    );
  }

  Widget _rangeBar() {
    const keys   = ['7d', '14d', '28d'];
    const labels = ['7 Days', '14 Days', '28 Days'];
    return Row(children: List.generate(3, (i) {
      final active = _range == keys[i];
      return Expanded(child: GestureDetector(
        onTap: () => setState(() => _range = keys[i]),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: active ? kAccent.withValues(alpha: 0.12) : kCard,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: active ? kAccent : kBorder)),
          child: Text(labels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: active ? kAccent : kTextSecondary)),
        ),
      ));
    }));
  }

  Widget _statPill(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: kTextSecondary)),
      ]),
    ));
  }

  Widget _miniStat(String label, String value, Color color) => Row(children: [
    Text(label, style: TextStyle(fontSize: 11, color: kTextSecondary)),
    const SizedBox(width: 4),
    Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  ]);

  Widget _microBadge(String label, int value) {
    final col = value <= 2 ? kAccent : value == 3 ? kWarn : kDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: col.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: col.withValues(alpha: 0.30))),
      child: Text('$label $value',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: col)),
    );
  }

  Widget _readyBadge(String label, int value) {
    final col = value <= 2 ? kAccent : value == 3 ? kWarn : kDanger;
    return Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: col.withValues(alpha: 0.10),
            border: Border.all(color: col.withValues(alpha: 0.35))),
        child: Center(child: Text('$value',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: col))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 9, color: kTextSecondary)),
    ]);
  }

  Widget _ldot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 10, color: kTextSecondary)),
  ]);

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
    child: child,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _acwrColor(double v) {
    if (v < 0.8)  return kInfo;
    if (v <= 1.3) return kSuccess;
    if (v <= 1.5) return kWarn;
    return kDanger;
  }

  String _acwrZone(double v) {
    if (v < 0.8)  return 'Undertraining';
    if (v <= 1.3) return 'Sweet Spot';
    if (v <= 1.5) return 'Caution';
    return 'Danger Zone';
  }

  String _readinessLabel(double pct) {
    if (pct >= 0.70) return 'Peak Ready';
    if (pct >= 0.50) return 'Good';
    if (pct >= 0.35) return 'Moderate';
    return 'Low';
  }

  String _ratingLabel(int v) {
    const labels = {1: 'Excellent', 2: 'Good', 3: 'Moderate', 4: 'Poor', 5: 'Very Poor'};
    return labels[v] ?? 'Very Poor';
  }
}

// ── Load vs Exertion Painter (bars = load, line = exertion 0–10) ──────────────

class _LoadExertionPainter extends CustomPainter {
  final List<_WP> data;
  final Color barColor;
  _LoadExertionPainter({required this.data, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final n = data.length;
    const bPad = 18.0, tPad = 12.0;
    final chartH = size.height - bPad - tPad;
    final slotW = size.width / n;
    final barW = min(slotW * 0.55, 26.0);
    final maxBar = data.fold(0.0, (p, w) => w.load > p ? w.load : p).clamp(1.0, 1e9);

    // Track background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, tPad, size.width, chartH), const Radius.circular(4)),
      Paint()..color = kTextPrimary.withValues(alpha: 0.04),
    );

    // Bars = load
    final bp = Paint()..color = barColor.withValues(alpha: 0.75);
    for (int i = 0; i < n; i++) {
      final x = i * slotW + (slotW - barW) / 2;
      final bh = (data[i].load / maxBar) * chartH * 0.82;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - bPad - bh, barW, bh), const Radius.circular(3)),
        bp,
      );
    }

    // Line = exertion on a fixed 0–10 scale
    double lineY(double v) => tPad + chartH * (1 - v.clamp(0, 10) / 10.0);
    final lp = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = i * slotW + slotW / 2;
      final y = lineY(data[i].exertion);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, lp);
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(i * slotW + slotW / 2, lineY(data[i].exertion)), 2.0,
        Paint()..color = Colors.pinkAccent);
    }

    // Date labels
    final step = (n / 5).ceil().clamp(1, n);
    for (int i = 0; i < n; i += step) {
      final tp = TextPainter(
        text: TextSpan(text: data[i].d.split('/')[0],
            style: TextStyle(color: kTextMuted, fontSize: 7.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * slotW + slotW / 2 - tp.width / 2, size.height - bPad + 4));
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

    // Zone bands
    void band(double lo, double hi, Color c) =>
        canvas.drawRect(Rect.fromLTRB(0, yAt(hi), w, yAt(lo)), Paint()..color = c);
    band(1.5, 2.0, kDanger.withValues(alpha: 0.07));
    band(1.3, 1.5, kWarn.withValues(alpha: 0.07));
    band(0.8, 1.3, kSuccess.withValues(alpha: 0.07));
    band(0.0, 0.8, kInfo.withValues(alpha: 0.06));

    // Threshold lines
    for (final v in [0.8, 1.3, 1.5]) {
      canvas.drawLine(Offset(0, yAt(v)), Offset(w, yAt(v)),
          Paint()..color = kTextPrimary.withValues(alpha: 0.09)..strokeWidth = 0.5);
    }

    final vals = data.map((p) => p.acwr.clamp(vMin, vMax)).toList();
    final pts  = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));

    // Area fill
    final fill = Path()..moveTo(pts.first.dx, h)..lineTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    fill..lineTo(pts.last.dx, h)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // Line
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = 2.0
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Last dot
    canvas.drawCircle(pts.last, 4.5, Paint()..color = color);
    canvas.drawCircle(pts.last, 4.5, Paint()
      ..color = kTextPrimary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0);
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
    const maxH = 0.68;

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
      final barH    = size.height * maxH * severity;
      // Narrow bars: at 0.62 of the slot they came out wider than they were
      // tall, so height differences read as noise next to the block of colour.
      final barW    = slotW * 0.36;
      final x       = i * slotW + (slotW - barW) / 2;
      final y       = size.height * maxH - barH;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, barH), const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: isLast ? 1.0 : 0.40),
      );

      // Value above bar
      final tv = TextPainter(
        text: TextSpan(text: '${values[i]}', style: TextStyle(
          color: isLast ? color : color.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tv.paint(canvas, Offset(i * slotW + slotW / 2 - tv.width / 2, max(0, y - 12)));

      // Day label
      final dayLbl = labels[i].split('/')[0];
      final td = TextPainter(
        text: TextSpan(text: dayLbl, style: TextStyle(color: kGrid, fontSize: 8.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      td.paint(canvas, Offset(i * slotW + slotW / 2 - td.width / 2, size.height * maxH + 4));
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
    final radius   = size.width / 2 - 8;
    final startRad = _startDeg * pi / 180;
    final sweepRad = _sweepDeg * pi / 180;
    const strokeW  = 9.0;
    final arcRect  = Rect.fromCircle(center: center, radius: radius - strokeW / 2);

    // Track
    canvas.drawArc(arcRect, startRad, sweepRad, false, Paint()
      ..color = color.withValues(alpha: 0.15)
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
    final fs = size.width * 0.20;
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: exertion.toStringAsFixed(1),
          style: TextStyle(color: kTextPrimary, fontSize: fs, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 3));

    // "/10"
    final tp2 = TextPainter(
      text: TextSpan(text: '/10', style: TextStyle(color: kTextSecondary, fontSize: fs * 0.42)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, center - Offset(tp2.width / 2, tp.height / 2 + 3 - fs * 0.90));
  }

  @override
  bool shouldRepaint(_ExertionArcPainter old) => old.exertion != exertion;
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
    const bPad = 18.0, tPad = 6.0, lPad = 22.0;
    final chartH = size.height - bPad - tPad;
    final chartW = size.width - lPad;
    const vMin = 4.0, vMax = 20.0;

    double yAt(double v) => tPad + chartH * (1 - (v - vMin) / (vMax - vMin));
    double xAt(int i) => lPad + chartW * i / (n - 1);

    // Zone bands
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(8), size.width, yAt(4)),
        Paint()..color = kSuccess.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(13), size.width, yAt(8)),
        Paint()..color = kWarn.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(20), size.width, yAt(13)),
        Paint()..color = kDanger.withValues(alpha: 0.06));

    // Reference lines at 8 and 13 (PDF requirement)
    for (final entry in [[8.0, kSuccess], [13.0, kDanger]]) {
      final v = entry[0] as double;
      final c = entry[1] as Color;
      final y = yAt(v);
      double x = lPad;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 5, size.width), y),
            Paint()..color = c.withValues(alpha: 0.5)..strokeWidth = 1.0);
        x += 9;
      }
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(0),
            style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 8.5, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    // Y axis ticks
    for (final v in [4.0, 12.0, 20.0]) {
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(0),
            style: TextStyle(color: kGrid, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (v != 4 && v != 20) tp.paint(canvas, Offset(2, yAt(v) - tp.height / 2));
    }

    final pts = List.generate(n, (i) => Offset(xAt(i), yAt(totals[i].toDouble())));

    // Smooth line
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[0];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(path, Paint()
      ..color = kViolet..strokeWidth = 2.2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Dots, coloured by zone
    for (int i = 0; i < n; i++) {
      final v = totals[i];
      final c = v <= 8 ? kAccent : v <= 13 ? kWarn : kDanger;
      canvas.drawCircle(pts[i], i == n - 1 ? 4.0 : 2.6, Paint()..color = c);
    }

    // Date labels
    final step = max(1, n ~/ 5);
    for (int i = 0; i < n; i += step) {
      final lbl = dates[i].split('/')[0];
      final tp = TextPainter(
        text: TextSpan(text: lbl, style: TextStyle(color: kGrid, fontSize: 7.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, size.height - bPad + 4));
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
    final radius  = size.width / 2 - 8;
    const strokeW = 10.0;

    canvas.drawCircle(center, radius, Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke..strokeWidth = strokeW);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 2 * pi * pct.clamp(0.0, 1.0), false,
      Paint()
        ..color = color..strokeWidth = strokeW
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ReadinessRingPainter old) => old.pct != pct || old.color != color;
}
