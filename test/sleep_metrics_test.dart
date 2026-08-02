import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/services/sleep_metrics.dart';

// Each test names the formula from the sleep assessment sheet that it pins.

void main() {
  group('formula 1 — sleep time', () {
    test('wake minus fell-asleep, less time awake', () {
      final n = SleepNight(
        d: '01/05',
        timeToBed: hm(22, 30),
        fellAsleep: hm(22, 50),
        wokeUp: hm(6, 30),
        outOfBed: hm(6, 30),
        awakeMinutes: 20,
      );
      // 22:50 → 06:30 is 7h40m, less 20m awake = 7h20m.
      expect(n.sleepMinutes, 440);
    });

    test('wraps across midnight when sleep starts after 00:00', () {
      final n = SleepNight(
        d: '02/05',
        timeToBed: hm(23, 40),
        fellAsleep: hm(0, 20),
        wokeUp: hm(7, 0),
        outOfBed: hm(7, 15),
      );
      expect(n.sleepMinutes, 400); // 00:20 → 07:00
    });

    test('never reports negative sleep when awake time exceeds the night', () {
      final n = SleepNight(
        d: '03/05',
        timeToBed: hm(1, 0),
        fellAsleep: hm(1, 30),
        wokeUp: hm(3, 0),
        outOfBed: hm(3, 0),
        awakeMinutes: 200,
      );
      expect(n.sleepMinutes, 0);
    });
  });

  group('formulae 2, 4, 7 — hh:mm rendering', () {
    test('zero-pads both fields', () {
      expect(formatHhMm(440), '07:20');
      expect(formatHhMm(5), '00:05');
      expect(formatHhMm(0), '00:00');
    });

    test('renders past 24h without wrapping', () {
      expect(formatHhMm(1500), '25:00');
    });
  });

  group('formula 5 — sleep efficiency', () {
    test('divides sleep time by out-of-bed minus time-to-bed', () {
      final n = SleepNight(
        d: '04/05',
        timeToBed: hm(22, 0),
        fellAsleep: hm(22, 30),
        wokeUp: hm(6, 0),
        outOfBed: hm(6, 30),
        awakeMinutes: 30,
      );
      // Sleep 7h00m over 8h30m in bed.
      expect(n.timeInBedMinutes, 510);
      expect(n.sleepMinutes, 420);
      expect(n.efficiency, closeTo(420 / 510, 1e-9));
    });

    test('lying in bed awake after waking lowers efficiency', () {
      SleepNight at(int outH, int outM) => SleepNight(
            d: 'x',
            timeToBed: hm(22, 0),
            fellAsleep: hm(22, 15),
            wokeUp: hm(6, 0),
            outOfBed: hm(outH, outM),
          );
      expect(at(6, 45).efficiency, lessThan(at(6, 0).efficiency));
    });

    test('returns 0 rather than throwing on a zero-length night', () {
      final n = SleepNight(
        d: '05/05',
        timeToBed: hm(22, 0),
        fellAsleep: hm(22, 0),
        wokeUp: hm(22, 0),
        outOfBed: hm(22, 0),
      );
      expect(n.efficiency, 0.0);
    });
  });

  group('formula 3 — 7-day average', () {
    // Seven identical 8h nights: the average must land exactly on 8h.
    final steady = List.generate(
      7,
      (i) => nightFromLog(
        d: '$i',
        timeToBed: hm(22, 0),
        latencyMinutes: 0,
        wokeUp: hm(6, 0),
      ),
    );

    test('averages a full window to the nightly value', () {
      expect(averageSleepMinutes(steady, 6), 480);
    });

    test('divides by the nights actually in the window, not a fixed 7', () {
      // Row 0 sees only one 8h night, so the average is that night's value —
      // not diluted by dividing a single night's total by 7.
      expect(averageSleepMinutes(steady, 0), 480);
      expect(averageSleepMinutes(steady, 3), 480);
    });

    test('window is the night plus the six before it, not the whole log', () {
      final nights = [
        ...List.generate(
          7,
          (i) => nightFromLog(
              d: 'old $i',
              timeToBed: hm(22, 0),
              latencyMinutes: 0,
              wokeUp: hm(2, 0)), // 4h
        ),
        ...List.generate(
          7,
          (i) => nightFromLog(
              d: 'new $i',
              timeToBed: hm(22, 0),
              latencyMinutes: 0,
              wokeUp: hm(6, 0)), // 8h
        ),
      ];
      // The last index sees only the seven recent 8h nights.
      expect(averageSleepMinutes(nights, 13), 480);
    });

    test('is safe on an empty log or out-of-range index', () {
      expect(averageSleepMinutes([], 0), 0);
      expect(averageSleepMinutes(steady, 99), 0);
    });
  });

  group('formula 6 — sleep debt', () {
    test('is the weekly average minus that night, when short', () {
      final nights = [
        ...List.generate(
          6,
          (i) => nightFromLog(
              d: 'a $i',
              timeToBed: hm(22, 0),
              latencyMinutes: 0,
              wokeUp: hm(6, 0)), // 8h
        ),
        nightFromLog(
            d: 'short',
            timeToBed: hm(23, 0),
            latencyMinutes: 0,
            wokeUp: hm(5, 0)), // 6h
      ];
      // Average = (6*480 + 360)/7 = 462; debt = 462 - 360 = 102.
      expect(averageSleepMinutes(nights, 6), 462);
      expect(sleepDebtMinutes(nights, 6), 102);
    });

    test('is zero — not blank — for a night exactly on the average', () {
      // The sheet blanks only on a negative difference, so an on-average night
      // is a real 00:00 debt rather than an empty cell.
      final nights = List.generate(
        7,
        (i) => nightFromLog(
            d: '$i', timeToBed: hm(22, 0), latencyMinutes: 0, wokeUp: hm(6, 0)),
      );
      expect(sleepDebtMinutes(nights, 6), 0);
    });

    test('is null — the sheet blanks the cell — when the night beats average', () {
      final nights = [
        ...List.generate(
          6,
          (i) => nightFromLog(
              d: 'a $i',
              timeToBed: hm(23, 0),
              latencyMinutes: 0,
              wokeUp: hm(5, 0)), // 6h
        ),
        nightFromLog(
            d: 'long',
            timeToBed: hm(22, 0),
            latencyMinutes: 0,
            wokeUp: hm(7, 0)), // 9h — well above the running average
      ];
      expect(sleepDebtMinutes(nights, 6), isNull);
    });

    test('is null on an empty log', () {
      expect(sleepDebtMinutes([], 0), isNull);
    });
  });

  group('nightFromLog', () {
    test('derives fell-asleep from bedtime plus latency', () {
      final n = nightFromLog(
        d: 'x',
        timeToBed: hm(23, 50),
        latencyMinutes: 30,
        wokeUp: hm(6, 0),
      );
      expect(n.fellAsleep, hm(0, 20)); // wraps past midnight
      expect(n.sleepLatencyMinutes, 30);
    });

    test('falls back to wake-up when no out-of-bed time is logged', () {
      final n = nightFromLog(
        d: 'x',
        timeToBed: hm(22, 0),
        latencyMinutes: 15,
        wokeUp: hm(6, 0),
      );
      expect(n.outOfBed, hm(6, 0));
      expect(n.timeInBedMinutes, 480);
    });
  });
}
