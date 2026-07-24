import 'dart:math';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../core/theme.dart';
import 'sleep_metrics.dart';

// ─── Shared dashboard data & metrics ────────────────────────────────────────
//
// Single source of truth for the athlete workload / recovery series and the
// headline metrics shown on the home dashboard rings. The home tab, the full
// stats screen, and the workload monitor all read from here, so the rings can
// never drift from the history/interpretation screens.
//
// All series are computed from the athlete's REAL synced training sessions
// (ApiService.fetchSessions). The rolling-metric formulas are a direct port
// of backend/utils/metrics.js — the backend's canonical implementation used
// by the admin dashboard — so athlete and coach views agree:
//   • acute   = trailing 7-calendar-day load sum ÷ 7
//   • chronic = EWMA of the acute series, λ = 2/29
//   • acwr    = acute ÷ chronic
//   • z       = (day load − chronic) ÷ population σ of day loads so far

class WorkPoint {
  final String d; // 'dd/MM' axis label
  final DateTime date;
  final double load, acute, chronic, acwr, z;
  const WorkPoint({
    required this.d,
    required this.date,
    required this.load,
    required this.acute,
    required this.chronic,
    required this.acwr,
    required this.z,
  });

  /// Session RPE-style exertion on a fixed 0–10 scale, derived from load.
  double get exertion =>
      load > 0 ? min(10.0, 2.087 * log(load / 50.0 + 1.0) + 2.0) : 2.0;
}

class RecoveryPoint {
  final String d;
  final DateTime date;
  final int sleep, wellness, soreness, fatigue; // 1 = excellent, 5 = poor
  const RecoveryPoint({
    required this.d,
    required this.date,
    required this.sleep,
    required this.wellness,
    required this.soreness,
    required this.fatigue,
  });

  /// Readiness as a 0–1 fraction (higher = more recovered).
  double get readinessPct =>
      (5.0 - (sleep + wellness + soreness + fatigue) / 4.0) / 4.0;
}

// ─── Tomorrow's load targets (chronic × 0.8–1.3 sweet-spot band) ────────────

class LoadTarget {
  final String label;
  final double chronic;
  final Color color;
  const LoadTarget({required this.label, required this.chronic, required this.color});
  double get low => chronic * 0.8;
  double get high => chronic * 1.3;
}

class CombinedLoadTarget {
  final LoadTarget total;
  final List<LoadTarget> parts;
  const CombinedLoadTarget(this.total, this.parts);
}

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
double loadBalance(double acwr) =>
    (1.0 - (acwr - 1.05).abs() / 1.05).clamp(0.0, 1.0);

/// Composite performance = 60% recovery readiness + 40% training-load balance.
double compositePerformance(double readiness, double acwr) =>
    (0.6 * readiness + 0.4 * loadBalance(acwr)).clamp(0.0, 1.0);

// ─── The athlete's computed metrics bundle ──────────────────────────────────

class AthleteMetrics {
  /// Per-day series, oldest first, contiguous from the first session day
  /// through today (zero-load days included so rolling windows are honest).
  /// train = primary + secondary session load; skill = skill session load.
  final List<WorkPoint> train, skill, total;

  /// One point per day that has a wellness check-in, oldest first.
  final List<RecoveryPoint> recovery;

  /// One night per day that has bed & wake times logged, oldest first.
  final List<SleepNight> sleep;

  const AthleteMetrics({
    required this.train,
    required this.skill,
    required this.total,
    required this.recovery,
    required this.sleep,
  });

  static const empty = AthleteMetrics(
      train: [], skill: [], total: [], recovery: [], sleep: []);

  bool get hasLoadData => total.any((p) => p.load > 0);
  bool get hasRecoveryData => recovery.isNotEmpty;
  bool get hasData => hasLoadData || hasRecoveryData;

  /// The three headline ring metrics — same windows/formulas the stats tabs use.
  HomeMetrics homeMetrics() {
    // Recovery — 7-day average readiness (matches the Recovery tab headline).
    final last7 = recovery.sublist(max(0, recovery.length - 7));
    final rec = last7.isEmpty
        ? 0.0
        : last7.map((r) => r.readinessPct).reduce((a, b) => a + b) / last7.length;

    // Today — today's daily-total exertion (the series is padded through
    // today, so `last` is today). A day with nothing logged reads 0, not the
    // exertion formula's 2.0 floor — the floor is for real sessions, and a
    // rest day showing "2.0" looks like phantom data.
    final todayExertion =
        total.isEmpty || total.last.load <= 0 ? 0.0 : total.last.exertion;

    // Performance — composite using the same 7-day readiness and latest ACWR.
    final latestAcwr = total.isEmpty ? 0.0 : total.last.acwr;
    final performance =
        recovery.isEmpty ? 0.0 : compositePerformance(rec, latestAcwr);

    // Trend — rolling 7-day-readiness composite per check-in day, each point
    // pairing that day's readiness window with that day's ACWR. The last
    // point equals the performancePct ring only when the latest check-in is
    // today (its ACWR then being today's); on days with no fresh check-in the
    // ring reflects "now" while the sparkline ends at the last logged day.
    final acwrByDay = {for (final t in total) _dayKey(t.date): t.acwr};
    final trend = <double>[];
    for (var i = max(0, recovery.length - 8); i < recovery.length; i++) {
      final win = recovery.sublist(max(0, i - 6), i + 1);
      final r = win.map((e) => e.readinessPct).reduce((a, b) => a + b) / win.length;
      final acwr = acwrByDay[_dayKey(recovery[i].date)] ?? latestAcwr;
      trend.add((compositePerformance(r, acwr) * 100).roundToDouble());
    }

    return HomeMetrics(
      performancePct: performance,
      recoveryPct: rec,
      todayExertion: todayExertion,
      performanceTrend: trend,
    );
  }

  /// Tomorrow's sweet-spot load band per stream, from each series' chronic load.
  CombinedLoadTarget loadTargets() => CombinedLoadTarget(
        LoadTarget(
            label: 'Total',
            chronic: total.isEmpty ? 0 : total.last.chronic,
            color: kViolet),
        [
          LoadTarget(
              label: 'Training',
              chronic: train.isEmpty ? 0 : train.last.chronic,
              color: kSky),
          LoadTarget(
              label: 'Skill',
              chronic: skill.isEmpty ? 0 : skill.last.chronic,
              color: kSuccess),
        ],
      );
}

// ─── Fetch + compute service (cached per app session) ───────────────────────

class AthleteMetricsService {
  AthleteMetricsService._();

  /// How much history feeds the rolling metrics. 90 days is ample for the
  /// λ = 2/29 chronic EWMA to converge, while keeping payloads small.
  static const historyDays = 90;

  static AthleteMetrics? _cache;
  static Future<AthleteMetrics>? _inflight;

  /// Loads (or returns the cached) metrics bundle for the signed-in athlete.
  static Future<AthleteMetrics> load({bool refresh = false}) {
    if (!refresh && _cache != null) return Future.value(_cache);
    // Share one in-flight fetch between screens racing at startup.
    return _inflight ??= _compute().then((m) {
      _cache = m;
      return m;
    }).whenComplete(() => _inflight = null);
  }

  /// Call after logging/deleting a session so the next screen recomputes.
  static void invalidate() {
    _cache = null;
  }

  static Future<AthleteMetrics> _compute() async {
    final from = DateTime.now().subtract(const Duration(days: historyDays));
    final sessions = await ApiService.fetchSessions(from: from, limit: 1000);
    return computeFromSessions(sessions, now: DateTime.now());
  }

  /// Pure computation, separated from fetching for testability.
  static AthleteMetrics computeFromSessions(
    List<Map<String, dynamic>> sessions, {
    required DateTime now,
  }) {
    final parsed = <_ParsedSession>[];
    for (final s in sessions) {
      final date = DateTime.tryParse(s['date']?.toString() ?? '')?.toLocal();
      if (date == null) continue;
      parsed.add(_ParsedSession(date, s));
    }
    if (parsed.isEmpty) return AthleteMetrics.empty;
    parsed.sort((a, b) => a.date.compareTo(b.date));

    // Contiguous day grid: first session day → today.
    final firstDay = _dayOnly(parsed.first.date);
    final lastDay = _dayOnly(now);
    final dayCount = _daysBetween(firstDay, lastDay) + 1;

    final trainByDay = List<double>.filled(dayCount, 0);
    final skillByDay = List<double>.filled(dayCount, 0);
    final totalByDay = List<double>.filled(dayCount, 0);
    // Last wellness check-in / sleep log seen per day (later sessions win).
    final wellnessByDay = <int, _ParsedSession>{};
    final sleepByDay = <int, _ParsedSession>{};

    for (final p in parsed) {
      final idx = _daysBetween(firstDay, p.date);
      if (idx < 0 || idx >= dayCount) continue;
      trainByDay[idx] += p.primaryLoad + p.secondaryLoad;
      skillByDay[idx] += p.skillLoad;
      totalByDay[idx] += p.totalLoad;
      if (p.hasWellness) wellnessByDay[idx] = p;
      if (p.hasSleepTimes) sleepByDay[idx] = p;
    }

    List<WorkPoint> series(List<double> loads) {
      const lambda = 2 / 29;
      final points = <WorkPoint>[];
      double chronic = 0;
      double sum = 0, sumSq = 0; // running population σ of day loads
      for (var i = 0; i < dayCount; i++) {
        final date = _addDays(firstDay, i);
        final load = loads[i];

        double acuteSum = 0;
        for (var j = max(0, i - 6); j <= i; j++) {
          acuteSum += loads[j];
        }
        final acute = acuteSum / 7;

        chronic = i == 0 ? acute : acute * lambda + chronic * (1 - lambda);
        final acwr = chronic > 0 ? acute / chronic : 0.0;

        sum += load;
        sumSq += load * load;
        final n = i + 1;
        final mean = sum / n;
        final variance = max(0.0, sumSq / n - mean * mean);
        final sigma = sqrt(variance);
        final z = sigma == 0 ? 0.0 : (load - chronic) / sigma;

        points.add(WorkPoint(
          d: _label(date),
          date: date,
          load: load,
          acute: acute,
          chronic: chronic,
          acwr: acwr,
          z: z,
        ));
      }
      return points;
    }

    final recovery = <RecoveryPoint>[];
    for (final idx in wellnessByDay.keys.toList()..sort()) {
      final p = wellnessByDay[idx]!;
      final date = _addDays(firstDay, idx);
      recovery.add(RecoveryPoint(
        d: _label(date),
        date: date,
        sleep: p.intOr3('sleep'),
        wellness: p.intOr3('wellness'),
        soreness: p.intOr3('soreness'),
        fatigue: p.intOr3('fatigue'),
      ));
    }

    final sleep = <SleepNight>[];
    for (final idx in sleepByDay.keys.toList()..sort()) {
      final p = sleepByDay[idx]!;
      final bed = _clockMinutes(p.raw['sleepTimeToBed']);
      final wake = _clockMinutes(p.raw['sleepWakeUpTime']);
      if (bed == null || wake == null) continue;
      sleep.add(nightFromLog(
        d: _label(_addDays(firstDay, idx)),
        timeToBed: bed,
        latencyMinutes: 0, // not captured in the log — assume fell asleep at bedtime
        wokeUp: wake,
      ));
    }

    return AthleteMetrics(
      train: series(trainByDay),
      skill: series(skillByDay),
      total: series(totalByDay),
      recovery: recovery,
      sleep: sleep,
    );
  }
}

// ─── Internals ──────────────────────────────────────────────────────────────

class _ParsedSession {
  final DateTime date;
  final Map<String, dynamic> raw;
  _ParsedSession(this.date, this.raw);

  double _num(String key) => (raw[key] is num) ? (raw[key] as num).toDouble() : 0.0;

  double get primaryLoad => _num('primaryLoad');
  double get secondaryLoad => _num('secondaryLoad');
  double get skillLoad => _num('skillLoad');
  double get totalLoad {
    final t = _num('totalLoad');
    return t > 0 ? t : primaryLoad + secondaryLoad + skillLoad;
  }

  bool get hasWellness =>
      raw['sleep'] is num ||
      raw['wellness'] is num ||
      raw['soreness'] is num ||
      raw['fatigue'] is num;

  bool get hasSleepTimes =>
      _clockMinutes(raw['sleepTimeToBed']) != null &&
      _clockMinutes(raw['sleepWakeUpTime']) != null;

  /// Wellness scores default to 3 (neutral) when unlogged — mirrors the
  /// backend's readinessPercent computation.
  int intOr3(String key) {
    final v = raw[key];
    if (v is num) return v.round().clamp(1, 5);
    return 3;
  }
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days between two dates, DST-immune. Computing via elapsed hours
/// (`b.difference(a).inDays`) truncates across a 23-hour spring-forward day
/// and shifts the whole grid; doing the arithmetic on UTC midnights — which
/// have no DST — always yields exact whole days.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// Local midnight of the calendar day [n] days after [d] — via UTC so the
/// day count never drifts across a DST transition.
DateTime _addDays(DateTime d, int n) {
  final u = DateTime.utc(d.year, d.month, d.day).add(Duration(days: n));
  return DateTime(u.year, u.month, u.day);
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

String _label(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Parses "HH:MM" into minutes-of-day; null when absent or malformed.
int? _clockMinutes(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}
