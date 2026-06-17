import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../api_service.dart';
import 'workload_monitor_screen.dart';

// ── Aliases ───────────────────────────────────────────────────────────────────
const _kBg     = kBg;
const _kCard   = kCard;
const _kBorder = kBorder;
const _kTxtP   = kTextPrimary;
const _kTxtS   = kTextSecondary;
const _kTxtM   = kTextMuted;

// ── Data Models ───────────────────────────────────────────────────────────────

class _WP {
  final String d;
  final double load, acwr;
  const _WP(this.d, this.load, this.acwr);
  double get exertion =>
      load > 0 ? min(10.0, 2.087 * log(load / 50.0 + 1.0) + 2.0) : 2.0;
}

class _RP {
  final String d;
  final int sleep, wellness, soreness, fatigue; // 1=excellent, 5=poor
  const _RP(this.d, this.sleep, this.wellness, this.soreness, this.fatigue);
  double get readinessPct =>
      (5.0 - (sleep + wellness + soreness + fatigue) / 4.0) / 4.0;
}

// ── ATS-2025-001 ──────────────────────────────────────────────────────────────
const _a1Train = <_WP>[
  _WP('13/04',236,3.00),_WP('14/04',0,2.37),_WP('15/04',0,1.89),
  _WP('16/04',392,2.11),_WP('17/04',0,1.96),_WP('18/04',0,1.00),
  _WP('19/04',0,0.82), _WP('20/04',0,0.53), _WP('21/04',0,0.55),
  _WP('22/04',270,0.93),_WP('23/04',192,0.66),_WP('24/04',172,0.91),
  _WP('25/04',135,1.10),_WP('26/04',329,1.51),_WP('27/04',0,1.46),
  _WP('28/04',0,1.42), _WP('29/04',0,1.06), _WP('30/04',0,0.83),
  _WP('01/05',178,0.84),_WP('02/05',603,1.41),_WP('03/05',0,1.00),
  _WP('04/05',0,1.00), _WP('05/05',135,1.15),_WP('06/05',90,1.25),
  _WP('07/05',192,1.43),
];
const _a1Skill = <_WP>[
  _WP('13/04',112,0.96),_WP('14/04',270,1.02),_WP('15/04',96,1.10),
  _WP('16/04',310,1.44),_WP('17/04',160,1.37),_WP('18/04',160,1.52),
  _WP('19/04',90,1.47), _WP('20/04',36,1.35), _WP('21/04',0,1.02),
  _WP('22/04',0,0.91),  _WP('23/04',0,0.56),  _WP('24/04',0,0.37),
  _WP('25/04',120,0.34),_WP('26/04',0,0.23),  _WP('27/04',72,0.29),
  _WP('28/04',126,0.50),_WP('29/04',80,0.64), _WP('30/04',135,0.87),
  _WP('01/05',0,0.88),  _WP('02/05',72,0.81), _WP('03/05',0,0.82),
  _WP('04/05',0,0.71),  _WP('05/05',124,0.73),_WP('06/05',480,1.39),
  _WP('07/05',420,1.77),
];
const _a1Total = <_WP>[
  _WP('13/04',348,1.86),_WP('14/04',270,1.65),_WP('15/04',96,1.48),
  _WP('16/04',702,1.77),_WP('17/04',160,1.67),_WP('18/04',160,1.26),
  _WP('19/04',90,1.15), _WP('20/04',36,0.96), _WP('21/04',0,0.80),
  _WP('22/04',270,0.92),_WP('23/04',192,0.61),_WP('24/04',172,0.63),
  _WP('25/04',255,0.71),_WP('26/04',329,0.88),_WP('27/04',72,0.92),
  _WP('28/04',126,1.00),_WP('29/04',80,0.88), _WP('30/04',135,0.85),
  _WP('01/05',178,0.86),_WP('02/05',675,1.15),_WP('03/05',0,0.92),
  _WP('04/05',0,0.88),  _WP('05/05',259,0.98),_WP('06/05',570,1.31),
  _WP('07/05',612,1.58),
];

// ── ATS-2025-002 ──────────────────────────────────────────────────────────────
const _a2Train = <_WP>[
  _WP('13/04',540,1.70),_WP('14/04',445,1.54),_WP('15/04',600,1.60),
  _WP('16/04',335,1.45),_WP('17/04',105,1.42),_WP('18/04',390,1.33),
  _WP('20/04',371,1.22),_WP('21/04',186,1.07),_WP('22/04',240,0.89),
  _WP('23/04',301,0.88),_WP('24/04',320,0.99),_WP('25/04',0,0.79),
  _WP('26/04',0,0.80),  _WP('27/04',178,0.71),_WP('28/04',0,0.62),
  _WP('29/04',245,0.64),_WP('30/04',258,0.63),_WP('01/05',300,0.63),
  _WP('02/05',229,0.79),_WP('03/05',0,0.80),  _WP('04/05',270,0.87),
  _WP('05/05',236,1.03),_WP('06/05',270,1.04),_WP('07/05',258,1.04),
];
const _a2Skill = <_WP>[
  _WP('13/04',300,1.73),_WP('14/04',360,1.72),_WP('15/04',360,1.72),
  _WP('16/04',280,1.83),_WP('17/04',240,1.70),_WP('18/04',0,1.62),
  _WP('20/04',150,1.42),_WP('21/04',30,1.08), _WP('22/04',45,0.77),
  _WP('23/04',80,0.58), _WP('24/04',150,0.50),_WP('25/04',120,0.65),
  _WP('26/04',180,0.86),_WP('27/04',12,0.72), _WP('28/04',0,0.70),
  _WP('29/04',0,0.66),  _WP('30/04',180,0.80),_WP('01/05',175,0.84),
  _WP('02/05',100,0.82),_WP('03/05',0,0.61),  _WP('04/05',0,0.61),
  _WP('05/05',180,0.86),_WP('06/05',90,0.99), _WP('07/05',150,0.95),
];
const _a2Total = <_WP>[
  _WP('13/04',840,1.86),_WP('14/04',805,1.72),_WP('15/04',960,1.75),
  _WP('16/04',615,1.67),_WP('17/04',345,1.59),_WP('18/04',390,1.50),
  _WP('20/04',521,1.34),_WP('21/04',216,1.12),_WP('22/04',285,0.88),
  _WP('23/04',381,0.80),_WP('24/04',470,0.86),_WP('25/04',120,0.77),
  _WP('26/04',180,0.85),_WP('27/04',190,0.73),_WP('28/04',0,0.66),
  _WP('29/04',245,0.66),_WP('30/04',438,0.70),_WP('01/05',475,0.72),
  _WP('02/05',329,0.82),_WP('03/05',0,0.75),  _WP('04/05',270,0.80),
  _WP('05/05',416,0.99),_WP('06/05',360,1.04),_WP('07/05',408,1.03),
];

// ── Wellness History ──────────────────────────────────────────────────────────
const _well1 = <_RP>[
  _RP('24/04',2,2,3,3),_RP('25/04',3,2,2,2),_RP('26/04',2,3,3,3),
  _RP('27/04',2,2,2,2),_RP('28/04',3,3,3,3),_RP('29/04',2,2,2,3),
  _RP('30/04',2,2,2,2),_RP('01/05',3,3,3,3),_RP('02/05',2,2,3,4),
  _RP('03/05',3,3,3,3),_RP('04/05',2,2,2,2),_RP('05/05',2,2,2,2),
  _RP('06/05',3,3,3,4),_RP('07/05',2,2,2,3),
];
const _well2 = <_RP>[
  _RP('24/04',3,3,4,4),_RP('25/04',2,3,3,3),_RP('26/04',3,3,4,4),
  _RP('27/04',2,2,3,3),_RP('28/04',3,3,3,4),_RP('29/04',2,2,3,3),
  _RP('30/04',2,2,2,3),_RP('01/05',3,3,4,4),_RP('02/05',3,3,3,3),
  _RP('03/05',2,2,2,2),_RP('04/05',2,2,2,2),_RP('05/05',2,2,3,3),
  _RP('06/05',3,3,3,4),_RP('07/05',2,2,2,2),
];

// ── Sleep Detail History (effective sleep & time in bed, hrs) ──────────────────
class _SD {
  final String d;
  final double inBed;   // total time in bed (hrs)
  final double asleep;  // effective sleep (hrs)
  const _SD(this.d, this.inBed, this.asleep);
  double get efficiency => inBed > 0 ? (asleep / inBed * 100).clamp(0, 100) : 0;
  double get debt => max(0.0, 8.0 - asleep); // vs 8h nightly need
}

const _sleep1 = <_SD>[
  _SD('24/04', 8.2, 7.4), _SD('25/04', 7.5, 6.9), _SD('26/04', 8.0, 7.0),
  _SD('27/04', 8.5, 7.8), _SD('28/04', 7.2, 6.3), _SD('29/04', 8.3, 7.6),
  _SD('30/04', 8.6, 8.0), _SD('01/05', 7.0, 6.1), _SD('02/05', 7.8, 6.8),
  _SD('03/05', 7.3, 6.4), _SD('04/05', 8.4, 7.9), _SD('05/05', 8.5, 8.0),
  _SD('06/05', 7.1, 6.2), _SD('07/05', 8.2, 7.5),
];
const _sleep2 = <_SD>[
  _SD('24/04', 7.0, 5.9), _SD('25/04', 7.8, 6.9), _SD('26/04', 6.8, 5.6),
  _SD('27/04', 8.1, 7.4), _SD('28/04', 7.2, 6.1), _SD('29/04', 8.0, 7.2),
  _SD('30/04', 8.3, 7.6), _SD('01/05', 6.9, 5.7), _SD('02/05', 7.4, 6.5),
  _SD('03/05', 8.5, 8.0), _SD('04/05', 8.6, 8.1), _SD('05/05', 7.6, 6.7),
  _SD('06/05', 7.0, 5.9), _SD('07/05', 8.4, 7.8),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class PlayerDashboardScreen extends StatefulWidget {
  const PlayerDashboardScreen({super.key});

  @override
  State<PlayerDashboardScreen> createState() => _PDS();
}

class _PDS extends State<PlayerDashboardScreen> with SingleTickerProviderStateMixin {
  int    _athlete = 0;
  String _athleteLabel = 'ATS-2025-001';
  String _range   = '28d';
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
  List<_SD> get _sleepData => _athlete == 0 ? _sleep1 : _sleep2;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Text(
          'DASHBOARD',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 1.4),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(children: [
            const Divider(height: 1, color: _kBorder),
            TabBar(
              controller: _tabs,
              labelColor: kAccent,
              unselectedLabelColor: _kTxtS,
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
          _acwrPanel('Training Workload', _trainData, Colors.lightBlueAccent),
          const SizedBox(height: 12),
          _acwrPanel('Skill Workload',    _skillData, Colors.greenAccent),
          const SizedBox(height: 12),
          _acwrPanel('Daily Total',       _totalData, Colors.purpleAccent),
        ],
      ),
    );
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
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTxtP)),
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
            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: _kTxtM),
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
    final rColor = todayR >= 0.60 ? kAccent : todayR >= 0.35 ? Colors.orangeAccent : Colors.redAccent;

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
            const Text('READINESS SCORE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kTxtS, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            Text(_readinessLabel(avgPct),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: rColor, letterSpacing: -0.3)),
            const SizedBox(height: 3),
            Text('7-day avg  ·  Today ${(todayR * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: _kTxtS)),
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

        // Trend chart
        _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.insights_rounded, size: 14, color: _kTxtS),
            const SizedBox(width: 6),
            const Text('14-Day Wellness Trend',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 12, children: [
            _ldot(kSleep,              'Sleep'),
            _ldot(kAccent,             'Wellness'),
            _ldot(Colors.orangeAccent, 'Soreness'),
            _ldot(Colors.redAccent,    'Fatigue'),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _WellTrendPainter(data: well),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 4),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('1 = Excellent', style: TextStyle(fontSize: 9, color: _kTxtM)),
            Text('5 = Very Poor',  style: TextStyle(fontSize: 9, color: _kTxtM)),
          ]),
        ])),
        const SizedBox(height: 14),

        _metricBars('Sleep Quality',    well.map((r) => r.sleep).toList(),    kSleep,              well.map((r) => r.d).toList()),
        const SizedBox(height: 10),
        _metricBars('Wellness',         well.map((r) => r.wellness).toList(), kAccent,             well.map((r) => r.d).toList()),
        const SizedBox(height: 10),
        _metricBars('Muscle Soreness',  well.map((r) => r.soreness).toList(), Colors.orangeAccent, well.map((r) => r.d).toList()),
        const SizedBox(height: 10),
        _metricBars('Fatigue',          well.map((r) => r.fatigue).toList(),  Colors.redAccent,    well.map((r) => r.d).toList()),
      ]),
    );
  }

  Widget _metricBars(String title, List<int> values, Color color, List<String> dates) {
    final last7v = values.sublist(max(0, values.length - 7));
    final last7d = dates.sublist(max(0, dates.length - 7));
    final cur    = last7v.last;
    final col    = cur <= 2 ? kAccent : cur == 3 ? Colors.orangeAccent : Colors.redAccent;
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 14, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
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
        height: 68,
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
    final col    = cur <= 8 ? kAccent : cur <= 13 ? Colors.orangeAccent : Colors.redAccent;
    final zone   = cur <= 8 ? 'Optimal Recovery' : cur <= 13 ? 'Monitor — Moderate Load' : 'High Strain — Intervene';
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.stacked_line_chart_rounded, size: 14, color: _kTxtS),
        const SizedBox(width: 6),
        const Text('Cumulative Recovery Score',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
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
        _ldot(Colors.orangeAccent, '8–13  Caution'),
        _ldot(Colors.redAccent,    '> 13  Risk'),
      ]),
    ]));
  }

  // ── Sleep Summary Panel ─────────────────────────────────────────────────────

  Widget _sleepSummaryPanel(List<_SD> sleep) {
    final last7   = sleep.sublist(max(0, sleep.length - 7));
    final avgEff  = last7.map((s) => s.efficiency).reduce((a, b) => a + b) / last7.length;
    final debt    = last7.map((s) => s.debt).reduce((a, b) => a + b);
    final last    = sleep.last;
    final effCol  = avgEff >= 85 ? kAccent : avgEff >= 75 ? Colors.orangeAccent : Colors.redAccent;
    final debtCol = debt <= 3 ? kAccent : debt <= 7 ? Colors.orangeAccent : Colors.redAccent;
    final summary = avgEff >= 85 && debt <= 3
        ? 'Sleep is restorative — efficiency is high and accumulated debt is low. Maintain current routine.'
        : debt > 7
            ? 'Significant sleep debt has accrued this week. Prioritise earlier bedtimes and recovery naps.'
            : 'Sleep is adequate but inconsistent. Aim for steadier bedtimes to lift efficiency and clear debt.';
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.bedtime_rounded, size: 14, color: kSleep),
        const SizedBox(width: 6),
        const Text('Sleep Summary',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
        const Spacer(),
        Text('Last night ${last.asleep.toStringAsFixed(1)}h',
            style: const TextStyle(fontSize: 10, color: _kTxtS)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _sleepStat('Efficiency', '${avgEff.toStringAsFixed(0)}%', '7-day avg', effCol)),
        const SizedBox(width: 10),
        Expanded(child: _sleepStat('Sleep Debt', '${debt.toStringAsFixed(1)}h', 'vs 8h need', debtCol)),
        const SizedBox(width: 10),
        Expanded(child: _sleepStat('Time in Bed', '${last.inBed.toStringAsFixed(1)}h', 'last night', kSleep)),
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
          const Icon(Icons.lightbulb_outline_rounded, size: 14, color: kSleep),
          const SizedBox(width: 8),
          Expanded(child: Text(summary,
              style: const TextStyle(fontSize: 11.5, color: _kTxtS, height: 1.4))),
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
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kTxtP)),
      Text(sub, style: const TextStyle(fontSize: 9, color: _kTxtS)),
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
          const Icon(Icons.calendar_today_rounded, size: 15, color: _kTxtS),
          const SizedBox(width: 8),
          const Text('07 May 2025',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTxtP)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
            child: const Text("TODAY'S SUMMARY",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kAccent, letterSpacing: 0.8)),
          ),
        ])),
        const SizedBox(height: 14),

        // Exertion arc trio
        Row(children: [
          Expanded(child: _exertionArc('Training', train.exertion, Colors.lightBlueAccent)),
          const SizedBox(width: 10),
          Expanded(child: _exertionArc('Skill',    skill.exertion, Colors.greenAccent)),
          const SizedBox(width: 10),
          Expanded(child: _exertionArc('Total',    total.exertion, Colors.purpleAccent)),
        ]),
        const SizedBox(height: 14),

        // Session cards
        _sessionCard('Training',    train, Colors.lightBlueAccent, Icons.fitness_center_rounded),
        const SizedBox(height: 10),
        _sessionCard('Skill',       skill, Colors.greenAccent,     Icons.sports_cricket_rounded),
        const SizedBox(height: 10),
        _sessionCard('Daily Total', total, Colors.purpleAccent,    Icons.stacked_bar_chart_rounded),
        const SizedBox(height: 14),

        // Readiness today
        _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.favorite_rounded, size: 14, color: _kTxtS),
            const SizedBox(width: 6),
            const Text("Today's Readiness",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTxtP)),
            const Spacer(),
            () {
              final col = well.readinessPct >= 0.6 ? kAccent
                  : well.readinessPct >= 0.35 ? Colors.orangeAccent
                  : Colors.redAccent;
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
          color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder)),
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
          color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder)),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTxtP)),
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
          Text('ACWR', style: const TextStyle(fontSize: 9, color: _kTxtS, letterSpacing: 0.5)),
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
          color: _kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_rounded, size: 14, color: kAccent),
        const SizedBox(width: 6),
        Text(_athleteLabel,
            style: const TextStyle(
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
              color: active ? kAccent.withValues(alpha: 0.12) : _kCard,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: active ? kAccent : _kBorder)),
          child: Text(labels[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: active ? kAccent : _kTxtS)),
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
        Text(label, style: const TextStyle(fontSize: 9, color: _kTxtS)),
      ]),
    ));
  }

  Widget _miniStat(String label, String value, Color color) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 11, color: _kTxtS)),
    const SizedBox(width: 4),
    Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  ]);

  Widget _microBadge(String label, int value) {
    final col = value <= 2 ? kAccent : value == 3 ? Colors.orangeAccent : Colors.redAccent;
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
    final col = value <= 2 ? kAccent : value == 3 ? Colors.orangeAccent : Colors.redAccent;
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
      Text(label, style: const TextStyle(fontSize: 9, color: _kTxtS)),
    ]);
  }

  Widget _ldot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: _kTxtS)),
  ]);

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _kBorder)),
    child: child,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _acwrColor(double v) {
    if (v < 0.8)  return Colors.blueAccent;
    if (v <= 1.3) return Colors.greenAccent;
    if (v <= 1.5) return Colors.orangeAccent;
    return Colors.redAccent;
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
    band(1.5, 2.0, Colors.redAccent.withValues(alpha: 0.07));
    band(1.3, 1.5, Colors.orangeAccent.withValues(alpha: 0.07));
    band(0.8, 1.3, Colors.greenAccent.withValues(alpha: 0.07));
    band(0.0, 0.8, Colors.blueAccent.withValues(alpha: 0.06));

    // Threshold lines
    for (final v in [0.8, 1.3, 1.5]) {
      canvas.drawLine(Offset(0, yAt(v)), Offset(w, yAt(v)),
          Paint()..color = Colors.white.withValues(alpha: 0.09)..strokeWidth = 0.5);
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
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(_AcwrSparkPainter old) => old.data != data || old.color != color;
}

// ── Wellness Trend Painter ────────────────────────────────────────────────────

class _WellTrendPainter extends CustomPainter {
  final List<_RP> data;
  const _WellTrendPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final n = data.length;
    const bPad = 20.0, tPad = 6.0, lPad = 4.0;
    final chartH = size.height - bPad - tPad;
    final chartW = size.width - lPad;

    // y: 1=excellent=top, 5=poor=bottom
    double yAt(double v) => tPad + chartH * (v - 1) / 4.0;
    double xAt(int i) => lPad + chartW * i / (n - 1);

    // Zone bands
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(1), size.width, yAt(2)),
        Paint()..color = Colors.greenAccent.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(2), size.width, yAt(3)),
        Paint()..color = Colors.orangeAccent.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(3), size.width, yAt(5)),
        Paint()..color = Colors.redAccent.withValues(alpha: 0.05));

    // Grid
    for (final v in [2.0, 3.0, 4.0]) {
      canvas.drawLine(Offset(lPad, yAt(v)), Offset(size.width, yAt(v)),
          Paint()..color = Colors.white.withValues(alpha: 0.07)..strokeWidth = 0.5);
    }

    void drawSeries(List<double> vals, Color col, double sw) {
      final pts = List.generate(n, (i) => Offset(xAt(i), yAt(vals[i])));
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
        ..color = col..strokeWidth = sw
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
      canvas.drawCircle(pts.last, 2.5, Paint()..color = col);
    }

    drawSeries(data.map((r) => r.sleep.toDouble()).toList(),    kSleep,              1.8);
    drawSeries(data.map((r) => r.wellness.toDouble()).toList(), kAccent,             1.8);
    drawSeries(data.map((r) => r.soreness.toDouble()).toList(), Colors.orangeAccent, 1.5);
    drawSeries(data.map((r) => r.fatigue.toDouble()).toList(),  Colors.redAccent,    1.5);

    // Date labels
    final step = max(1, n ~/ 5);
    for (int i = 0; i < n; i += step) {
      final lbl = data[i].d.split('/')[0];
      final tp = TextPainter(
        text: TextSpan(text: lbl, style: const TextStyle(color: Color(0xFF5C6280), fontSize: 7.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, size.height - bPad + 4));
    }
    final lbl = data.last.d.split('/')[0];
    final tp = TextPainter(
      text: TextSpan(text: lbl, style: const TextStyle(color: Color(0xFF5C6280), fontSize: 7.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(xAt(n - 1) - tp.width / 2, size.height - bPad + 4));
  }

  @override
  bool shouldRepaint(_WellTrendPainter old) => old.data != data;
}

// ── Metric Bars Painter ───────────────────────────────────────────────────────

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
      final goodness = (6 - values[i]) / 5.0;
      final barH    = size.height * maxH * goodness;
      final barW    = slotW * 0.62;
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
        text: TextSpan(text: dayLbl, style: const TextStyle(color: Color(0xFF5C6280), fontSize: 8.5)),
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
          style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 3));

    // "/10"
    final tp2 = TextPainter(
      text: TextSpan(text: '/10', style: TextStyle(color: _kTxtS, fontSize: fs * 0.42)),
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
        Paint()..color = Colors.greenAccent.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(13), size.width, yAt(8)),
        Paint()..color = Colors.orangeAccent.withValues(alpha: 0.06));
    canvas.drawRect(Rect.fromLTRB(lPad, yAt(20), size.width, yAt(13)),
        Paint()..color = Colors.redAccent.withValues(alpha: 0.06));

    // Reference lines at 8 and 13 (PDF requirement)
    for (final entry in [[8.0, Colors.greenAccent], [13.0, Colors.redAccent]]) {
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
            style: const TextStyle(color: Color(0xFF5C6280), fontSize: 8)),
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
      ..color = Colors.purpleAccent..strokeWidth = 2.2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Dots, coloured by zone
    for (int i = 0; i < n; i++) {
      final v = totals[i];
      final c = v <= 8 ? kAccent : v <= 13 ? Colors.orangeAccent : Colors.redAccent;
      canvas.drawCircle(pts[i], i == n - 1 ? 4.0 : 2.6, Paint()..color = c);
    }

    // Date labels
    final step = max(1, n ~/ 5);
    for (int i = 0; i < n; i += step) {
      final lbl = dates[i].split('/')[0];
      final tp = TextPainter(
        text: TextSpan(text: lbl, style: const TextStyle(color: Color(0xFF5C6280), fontSize: 7.5)),
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
