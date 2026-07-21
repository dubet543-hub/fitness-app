// ─── Sleep assessment formulae ──────────────────────────────────────────────
//
// Dart implementation of the SolidCore ATS sleep spreadsheet
// ("List of formulae for Sleep assessment"). Column letters below refer to the
// source sheet so the two stay auditable against each other:
//
//   D = time to bed        E = fell asleep       F = woke up
//   G = got out of bed     I = awake after disturbance
//   K = sleep time         M = 7-day average     P = sleep debt
//
// Everything is kept in whole minutes internally — the sheet works in Excel day
// fractions, and minutes avoid the floating-point drift that comes with them.

/// One night of logged sleep. Clock fields are minutes from midnight (0–1439).
class SleepNight {
  final String d;            // label, dd/MM
  final int timeToBed;       // D
  final int fellAsleep;      // E
  final int wokeUp;          // F
  final int outOfBed;        // G
  final int awakeMinutes;    // I — time awake after a disturbance

  const SleepNight({
    required this.d,
    required this.timeToBed,
    required this.fellAsleep,
    required this.wokeUp,
    required this.outOfBed,
    this.awakeMinutes = 0,
  });

  /// Formula 1 — SLEEP TIME: MOD(F - E, 1) - I.
  /// Wake-up minus fell-asleep, wrapping past midnight, less time spent awake.
  int get sleepMinutes => (_wrap(wokeUp - fellAsleep) - awakeMinutes).clamp(0, 1440);

  /// Denominator of formula 5 — MOD(G - D, 1): got-out-of-bed minus time-to-bed.
  int get timeInBedMinutes => _wrap(outOfBed - timeToBed);

  /// Formula 5 — SLEEP EFFICIENCY: (MOD(F-E, 1) - I) / MOD(G-D, 1), as a
  /// 0–1 fraction. Returns 0 on a zero-length night, matching the sheet's
  /// IFERROR(…, 0).
  double get efficiency =>
      timeInBedMinutes > 0 ? sleepMinutes / timeInBedMinutes : 0.0;

  /// Minutes to fall asleep — E - D. Not a numbered formula, but it is the
  /// input the log screen actually collects.
  int get sleepLatencyMinutes => _wrap(fellAsleep - timeToBed);

  double get sleepHours => sleepMinutes / 60.0;
  double get timeInBedHours => timeInBedMinutes / 60.0;
}

/// Wraps a minute difference into [0, 1440) — the MOD(x, 1) of the sheet.
int _wrap(int diff) => ((diff % 1440) + 1440) % 1440;

/// Formulae 2, 4 and 7 — TEXT(value, "hh:mm").
/// Renders a minute count as zero-padded hh:mm.
String formatHhMm(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// Formula 3 — AVERAGE SLEEP TIME.
/// SUMIFS over the window (d-7, d] divided by 7: the given night plus the six
/// before it. Note the divisor is a literal 7, not the number of nights found,
/// so the first six rows of a log read low by design — that is what the sheet
/// does, and the debt figure below is calibrated against it.
int averageSleepMinutes(List<SleepNight> nights, int index) {
  if (nights.isEmpty || index < 0 || index >= nights.length) return 0;
  final start = index - 6 < 0 ? 0 : index - 6;
  var sum = 0;
  for (var i = start; i <= index; i++) {
    sum += nights[i].sleepMinutes;
  }
  return sum ~/ 7;
}

/// Formula 6 — SLEEP DEBT: weekly average (M) minus that night's sleep (K).
/// The sheet blanks the cell when the difference is negative — a night that
/// beats the average carries no debt — so this returns null rather than a
/// negative number.
int? sleepDebtMinutes(List<SleepNight> nights, int index) {
  if (nights.isEmpty || index < 0 || index >= nights.length) return null;
  final debt = averageSleepMinutes(nights, index) - nights[index].sleepMinutes;
  return debt < 0 ? null : debt;
}

/// Convenience: builds a night from the inputs the sleep log screen collects
/// (bedtime, minutes to fall asleep, wake-up, out-of-bed) rather than from raw
/// clock columns.
SleepNight nightFromLog({
  required String d,
  required int timeToBed,
  required int latencyMinutes,
  required int wokeUp,
  int? outOfBed,
  int awakeMinutes = 0,
}) =>
    SleepNight(
      d: d,
      timeToBed: timeToBed,
      fellAsleep: (timeToBed + latencyMinutes) % 1440,
      wokeUp: wokeUp,
      // The sheet needs a distinct out-of-bed time; when a log does not carry
      // one, lying-in time is unknown and wake-up is the best stand-in.
      outOfBed: outOfBed ?? wokeUp,
      awakeMinutes: awakeMinutes,
    );

/// Builds a clock value from hours/minutes, for terse literal data.
int hm(int hours, int minutes) => hours * 60 + minutes;
