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
  final double performancePct;         // 0–1  (today's readiness vs. exertion, asymmetric penalty)
  final double recoveryPct;            // 0–1  (today's readiness check-in)
  final double todayExertion;          // 0–10 (latest daily-total exertion)
  final List<double> performanceTrend; // recent composite %, oldest → newest
  const HomeMetrics({
    required this.performancePct,
    required this.recoveryPct,
    required this.todayExertion,
    required this.performanceTrend,
  });
}

/// Daily performance — ATS spreadsheet formula: an asymmetric penalty on the
/// gap between normalized exertion and readiness.
///   norm_exertion = (exertion − 2) / 8          — exertion's 2–10 range to 0–1
///   delta         = norm_exertion − readiness   — positive = overreaching
///   penalty       = 1.3·delta²  if delta > 0    — overreaching costs more…
///                 = 0.8·delta²  otherwise       — …than underreaching
///   result        = max(0, 1 − penalty)
/// Overreaching (pushed harder than today's readiness supports) is penalised
/// more steeply than underreaching (readiness banked but not spent).
double dailyPerformancePct(double readiness, double exertion) {
  final normExertion = (exertion - 2.0) / 8.0;
  final delta = normExertion - readiness;
  final penalty = delta > 0 ? 1.3 * delta * delta : 0.8 * delta * delta;
  return (1.0 - penalty).clamp(0.0, 1.0);
}

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
    // Readiness — today's wellness check-in (matches the stats "Today" tab).
    // Feeds both the Recovery ring and the composite Performance ring. Falls
    // back to 0 until the first check-in is logged.
    final todayReadiness = recovery.isEmpty ? 0.0 : recovery.last.readinessPct;

    // Today — today's daily-total exertion (the series is padded through
    // today, so `last` is today). A day with nothing logged reads 0, not the
    // exertion formula's 2.0 floor — the floor is for real sessions, and a
    // rest day showing "2.0" looks like phantom data.
    final todayExertion =
        total.isEmpty || total.last.load <= 0 ? 0.0 : total.last.exertion;

    // Performance — today's readiness vs. today's exertion (dailyPerformancePct).
    // Uses the raw exertion getter (2.0 floor on a rest day), not the
    // display-zeroed `todayExertion` above — the sheet's exertion never drops
    // below 2.
    final todayRawExertion = total.isEmpty ? 2.0 : total.last.exertion;
    final performance = recovery.isEmpty
        ? 0.0
        : dailyPerformancePct(todayReadiness, todayRawExertion);

    // Trend — the same formula per check-in day, each point pairing that
    // day's own readiness with that day's own exertion. The last point
    // equals the performancePct ring whenever the latest check-in is today.
    final exertionByDay = {for (final t in total) _dayKey(t.date): t.exertion};
    final trend = <double>[];
    for (var i = max(0, recovery.length - 8); i < recovery.length; i++) {
      final r = recovery[i].readinessPct;
      final ex = exertionByDay[_dayKey(recovery[i].date)] ?? todayRawExertion;
      trend.add((dailyPerformancePct(r, ex) * 100).roundToDouble());
    }

    return HomeMetrics(
      performancePct: performance,
      recoveryPct: todayReadiness,
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

  /// Ticks on every [invalidate]. Long-lived listeners — e.g. the Home tab,
  /// kept alive in an IndexedStack rather than rebuilt on tab switch — use
  /// this to refresh themselves the moment a session is logged, instead of
  /// waiting for their own next unrelated rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
    revision.value++;
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
    // Last wellness check-in seen per day wins. Sleep logs instead keep
    // whichever entry has the most sleep detail (see sleepDetailScore) so a
    // same-day duplicate never overwrites a fuller night's data with a
    // sparser one.
    final wellnessByDay = <int, _ParsedSession>{};
    final sleepByDay = <int, _ParsedSession>{};

    for (final p in parsed) {
      final idx = _daysBetween(firstDay, p.date);
      if (idx < 0 || idx >= dayCount) continue;
      trainByDay[idx] += p.primaryLoad + p.secondaryLoad;
      skillByDay[idx] += p.skillLoad;
      totalByDay[idx] += p.totalLoad;
      if (p.hasWellness) wellnessByDay[idx] = p;
      if (p.hasSleepTimes) {
        final existing = sleepByDay[idx];
        if (existing == null || p.sleepDetailScore >= existing.sleepDetailScore) {
          sleepByDay[idx] = p;
        }
      }
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
      // Fell-asleep and out-of-bed are logged separately from bedtime and
      // wake-up (see wellness_log_screen) — fall back to bed/wake only for
      // older entries recorded before those pickers existed.
      final asleep  = _clockMinutes(p.raw['sleepFellAsleep']) ?? bed;
      final outOfBed = _clockMinutes(p.raw['sleepOutOfBedTime']) ?? wake;
      sleep.add(SleepNight(
        d: _label(_addDays(firstDay, idx)),
        timeToBed: bed,
        fellAsleep: asleep,
        wokeUp: wake,
        outOfBed: outOfBed,
        // Without this, sleepMinutes/efficiency were recomputed from raw
        // clock times alone, silently dropping any logged disturbance time
        // everywhere sleep data is displayed (Sleep Monitor, dashboard card)
        // even though the wellness log's own preview subtracted it correctly.
        awakeMinutes: p._num('sleepDisturbanceMinutes').round(),
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

  /// How much sleep detail this entry actually carries: 0 when only bed/wake
  /// were logged, up to 2 once fell-asleep and out-of-bed are also present.
  /// Two wellness check-ins can land on the same local day (e.g. one logged
  /// just after waking, another logged later that same day) — both describe
  /// the same night, so the fuller one should win rather than whichever
  /// happened to be submitted last.
  int get sleepDetailScore =>
      (_clockMinutes(raw['sleepFellAsleep']) != null ? 1 : 0) +
      (_clockMinutes(raw['sleepOutOfBedTime']) != null ? 1 : 0);

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
