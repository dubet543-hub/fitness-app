import 'dart:math';

// ─── Shared dashboard data & metrics ────────────────────────────────────────
//
// Single source of truth for the athlete workload / recovery series and the
// headline metrics shown on the home dashboard rings. Both the home tab and the
// full stats screen read from here, so the rings can never drift from the
// history/interpretation screens.

class WorkPoint {
  final String d;
  final double load, acwr;
  const WorkPoint(this.d, this.load, this.acwr);

  /// Session RPE-style exertion on a fixed 0–10 scale, derived from load.
  double get exertion =>
      load > 0 ? min(10.0, 2.087 * log(load / 50.0 + 1.0) + 2.0) : 2.0;
}

class RecoveryPoint {
  final String d;
  final int sleep, wellness, soreness, fatigue; // 1 = excellent, 5 = poor
  const RecoveryPoint(this.d, this.sleep, this.wellness, this.soreness, this.fatigue);

  /// Readiness as a 0–1 fraction (higher = more recovered).
  double get readinessPct =>
      (5.0 - (sleep + wellness + soreness + fatigue) / 4.0) / 4.0;
}

// ── ATS-2025-001 ────────────────────────────────────────────────────────────
const kA1Train = <WorkPoint>[
  WorkPoint('13/04',236,3.00),WorkPoint('14/04',0,2.37),WorkPoint('15/04',0,1.89),
  WorkPoint('16/04',392,2.11),WorkPoint('17/04',0,1.96),WorkPoint('18/04',0,1.00),
  WorkPoint('19/04',0,0.82), WorkPoint('20/04',0,0.53), WorkPoint('21/04',0,0.55),
  WorkPoint('22/04',270,0.93),WorkPoint('23/04',192,0.66),WorkPoint('24/04',172,0.91),
  WorkPoint('25/04',135,1.10),WorkPoint('26/04',329,1.51),WorkPoint('27/04',0,1.46),
  WorkPoint('28/04',0,1.42), WorkPoint('29/04',0,1.06), WorkPoint('30/04',0,0.83),
  WorkPoint('01/05',178,0.84),WorkPoint('02/05',603,1.41),WorkPoint('03/05',0,1.00),
  WorkPoint('04/05',0,1.00), WorkPoint('05/05',135,1.15),WorkPoint('06/05',90,1.25),
  WorkPoint('07/05',192,1.43),
];
const kA1Skill = <WorkPoint>[
  WorkPoint('13/04',112,0.96),WorkPoint('14/04',270,1.02),WorkPoint('15/04',96,1.10),
  WorkPoint('16/04',310,1.44),WorkPoint('17/04',160,1.37),WorkPoint('18/04',160,1.52),
  WorkPoint('19/04',90,1.47), WorkPoint('20/04',36,1.35), WorkPoint('21/04',0,1.02),
  WorkPoint('22/04',0,0.91),  WorkPoint('23/04',0,0.56),  WorkPoint('24/04',0,0.37),
  WorkPoint('25/04',120,0.34),WorkPoint('26/04',0,0.23),  WorkPoint('27/04',72,0.29),
  WorkPoint('28/04',126,0.50),WorkPoint('29/04',80,0.64), WorkPoint('30/04',135,0.87),
  WorkPoint('01/05',0,0.88),  WorkPoint('02/05',72,0.81), WorkPoint('03/05',0,0.82),
  WorkPoint('04/05',0,0.71),  WorkPoint('05/05',124,0.73),WorkPoint('06/05',480,1.39),
  WorkPoint('07/05',420,1.77),
];
const kA1Total = <WorkPoint>[
  WorkPoint('13/04',348,1.86),WorkPoint('14/04',270,1.65),WorkPoint('15/04',96,1.48),
  WorkPoint('16/04',702,1.77),WorkPoint('17/04',160,1.67),WorkPoint('18/04',160,1.26),
  WorkPoint('19/04',90,1.15), WorkPoint('20/04',36,0.96), WorkPoint('21/04',0,0.80),
  WorkPoint('22/04',270,0.92),WorkPoint('23/04',192,0.61),WorkPoint('24/04',172,0.63),
  WorkPoint('25/04',255,0.71),WorkPoint('26/04',329,0.88),WorkPoint('27/04',72,0.92),
  WorkPoint('28/04',126,1.00),WorkPoint('29/04',80,0.88), WorkPoint('30/04',135,0.85),
  WorkPoint('01/05',178,0.86),WorkPoint('02/05',675,1.15),WorkPoint('03/05',0,0.92),
  WorkPoint('04/05',0,0.88),  WorkPoint('05/05',259,0.98),WorkPoint('06/05',570,1.31),
  WorkPoint('07/05',612,1.58),
];

// ── ATS-2025-002 ────────────────────────────────────────────────────────────
const kA2Train = <WorkPoint>[
  WorkPoint('13/04',540,1.70),WorkPoint('14/04',445,1.54),WorkPoint('15/04',600,1.60),
  WorkPoint('16/04',335,1.45),WorkPoint('17/04',105,1.42),WorkPoint('18/04',390,1.33),
  WorkPoint('20/04',371,1.22),WorkPoint('21/04',186,1.07),WorkPoint('22/04',240,0.89),
  WorkPoint('23/04',301,0.88),WorkPoint('24/04',320,0.99),WorkPoint('25/04',0,0.79),
  WorkPoint('26/04',0,0.80),  WorkPoint('27/04',178,0.71),WorkPoint('28/04',0,0.62),
  WorkPoint('29/04',245,0.64),WorkPoint('30/04',258,0.63),WorkPoint('01/05',300,0.63),
  WorkPoint('02/05',229,0.79),WorkPoint('03/05',0,0.80),  WorkPoint('04/05',270,0.87),
  WorkPoint('05/05',236,1.03),WorkPoint('06/05',270,1.04),WorkPoint('07/05',258,1.04),
];
const kA2Skill = <WorkPoint>[
  WorkPoint('13/04',300,1.73),WorkPoint('14/04',360,1.72),WorkPoint('15/04',360,1.72),
  WorkPoint('16/04',280,1.83),WorkPoint('17/04',240,1.70),WorkPoint('18/04',0,1.62),
  WorkPoint('20/04',150,1.42),WorkPoint('21/04',30,1.08), WorkPoint('22/04',45,0.77),
  WorkPoint('23/04',80,0.58), WorkPoint('24/04',150,0.50),WorkPoint('25/04',120,0.65),
  WorkPoint('26/04',180,0.86),WorkPoint('27/04',12,0.72), WorkPoint('28/04',0,0.70),
  WorkPoint('29/04',0,0.66),  WorkPoint('30/04',180,0.80),WorkPoint('01/05',175,0.84),
  WorkPoint('02/05',100,0.82),WorkPoint('03/05',0,0.61),  WorkPoint('04/05',0,0.61),
  WorkPoint('05/05',180,0.86),WorkPoint('06/05',90,0.99), WorkPoint('07/05',150,0.95),
];
const kA2Total = <WorkPoint>[
  WorkPoint('13/04',840,1.86),WorkPoint('14/04',805,1.72),WorkPoint('15/04',960,1.75),
  WorkPoint('16/04',615,1.67),WorkPoint('17/04',345,1.59),WorkPoint('18/04',390,1.50),
  WorkPoint('20/04',521,1.34),WorkPoint('21/04',216,1.12),WorkPoint('22/04',285,0.88),
  WorkPoint('23/04',381,0.80),WorkPoint('24/04',470,0.86),WorkPoint('25/04',120,0.77),
  WorkPoint('26/04',180,0.85),WorkPoint('27/04',190,0.73),WorkPoint('28/04',0,0.66),
  WorkPoint('29/04',245,0.66),WorkPoint('30/04',438,0.70),WorkPoint('01/05',475,0.72),
  WorkPoint('02/05',329,0.82),WorkPoint('03/05',0,0.75),  WorkPoint('04/05',270,0.80),
  WorkPoint('05/05',416,0.99),WorkPoint('06/05',360,1.04),WorkPoint('07/05',408,1.03),
];

// ── Wellness / recovery history ─────────────────────────────────────────────
const kWell1 = <RecoveryPoint>[
  RecoveryPoint('24/04',2,2,3,3),RecoveryPoint('25/04',3,2,2,2),RecoveryPoint('26/04',2,3,3,3),
  RecoveryPoint('27/04',2,2,2,2),RecoveryPoint('28/04',3,3,3,3),RecoveryPoint('29/04',2,2,2,3),
  RecoveryPoint('30/04',2,2,2,2),RecoveryPoint('01/05',3,3,3,3),RecoveryPoint('02/05',2,2,3,4),
  RecoveryPoint('03/05',3,3,3,3),RecoveryPoint('04/05',2,2,2,2),RecoveryPoint('05/05',2,2,2,2),
  RecoveryPoint('06/05',3,3,3,4),RecoveryPoint('07/05',2,2,2,3),
];
const kWell2 = <RecoveryPoint>[
  RecoveryPoint('24/04',3,3,4,4),RecoveryPoint('25/04',2,3,3,3),RecoveryPoint('26/04',3,3,4,4),
  RecoveryPoint('27/04',2,2,3,3),RecoveryPoint('28/04',3,3,3,4),RecoveryPoint('29/04',2,2,3,3),
  RecoveryPoint('30/04',2,2,2,3),RecoveryPoint('01/05',3,3,4,4),RecoveryPoint('02/05',3,3,3,3),
  RecoveryPoint('03/05',2,2,2,2),RecoveryPoint('04/05',2,2,2,2),RecoveryPoint('05/05',2,2,3,3),
  RecoveryPoint('06/05',3,3,3,4),RecoveryPoint('07/05',2,2,2,2),
];

// ─── Headline metrics for the home dashboard rings ──────────────────────────

class HomeMetrics {
  final double performancePct;         // 0–1  (composite: readiness + load balance)
  final double recoveryPct;            // 0–1  (7-day avg readiness)
  final double todayExertion;          // 0–10 (latest daily-total exertion)
  final List<double> performanceTrend; // recent composite %, oldest → newest
  const HomeMetrics({
    required this.performancePct,
    required this.recoveryPct,
    required this.todayExertion,
    required this.performanceTrend,
  });
}

/// ACWR "optimality" on a 0–1 scale: peaks at the ~1.05 sweet spot and falls off
/// as the acute:chronic ratio drifts toward detraining (<0.8) or spikes (>1.3).
double _loadBalance(double acwr) =>
    (1.0 - (acwr - 1.05).abs() / 1.05).clamp(0.0, 1.0);

/// Composite performance = 60% recovery readiness + 40% training-load balance.
double _composite(double readiness, double acwr) =>
    (0.6 * readiness + 0.4 * _loadBalance(acwr)).clamp(0.0, 1.0);

/// Derives the three headline ring metrics for the given logged-in athlete.
/// The athlete is resolved from the display name (matching the stats screen),
/// so the home rings mirror exactly what the history tabs compute.
HomeMetrics homeMetricsFor(String athleteName) {
  final isA2  = athleteName.contains('002');
  final total = isA2 ? kA2Total : kA1Total;
  final well  = isA2 ? kWell2   : kWell1;

  // Recovery — 7-day average readiness (matches the Recovery tab headline).
  final last7    = well.sublist(max(0, well.length - 7));
  final recovery = last7.map((r) => r.readinessPct).reduce((a, b) => a + b) / last7.length;

  // Today — latest daily-total exertion (matches the Today tab's Total arc).
  final todayExertion = total.last.exertion;

  // Performance — composite using the same 7-day readiness and latest ACWR.
  final performance = _composite(recovery, total.last.acwr);

  // Trend — rolling 7-day-readiness composite per day; the last point equals the
  // ring value, since it uses the same window and the latest ACWR.
  final acwrByDate = {for (final t in total) t.d: t.acwr};
  final trend = <double>[];
  for (var i = max(0, well.length - 8); i < well.length; i++) {
    final win = well.sublist(max(0, i - 6), i + 1);
    final r   = win.map((e) => e.readinessPct).reduce((a, b) => a + b) / win.length;
    final acwr = acwrByDate[well[i].d] ?? total.last.acwr;
    trend.add((_composite(r, acwr) * 100).roundToDouble());
  }

  return HomeMetrics(
    performancePct: performance,
    recoveryPct: recovery,
    todayExertion: todayExertion,
    performanceTrend: trend,
  );
}
