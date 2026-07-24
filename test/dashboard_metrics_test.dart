import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/services/dashboard_metrics.dart';

// ─── Formula-fidelity tests for AthleteMetricsService.computeFromSessions ───
//
// Pins the rolling-workload math to the canonical implementation in
// backend/utils/metrics.js (loadSummary / exertion / loadBalance /
// performance), evaluated on the app's contiguous per-day grid:
//
//   acute_i   = (sum of day loads over days i-6 .. i) / 7      (trailing 7d)
//   chronic_0 = acute_0                                        (EWMA seed)
//   chronic_i = acute_i·λ + chronic_{i-1}·(1−λ),  λ = 2/29
//   acwr_i    = acute_i / chronic_i   (0 when chronic_i == 0)
//   z_last    = (load_last − chronic_last) / populationσ(all day loads)
//
// Every expected number below is derived by hand in the comments so a future
// formula change fails loudly against auditable arithmetic.
//
// All fixture dates live in July 2026: no timezone observes a DST transition
// that month, so local-midnight day arithmetic is stable wherever CI runs.

/// Builds a session map shaped like the backend TrainingSession JSON.
Map<String, dynamic> session(
  String isoDate, {
  num? primaryLoad,
  num? secondaryLoad,
  num? skillLoad,
  num? totalLoad,
  num? sleep,
  num? wellness,
  num? soreness,
  num? fatigue,
  String? sleepTimeToBed,
  String? sleepWakeUpTime,
}) =>
    <String, dynamic>{
      'date': isoDate,
      'primaryLoad': ?primaryLoad,
      'secondaryLoad': ?secondaryLoad,
      'skillLoad': ?skillLoad,
      'totalLoad': ?totalLoad,
      'sleep': ?sleep,
      'wellness': ?wellness,
      'soreness': ?soreness,
      'fatigue': ?fatigue,
      'sleepTimeToBed': ?sleepTimeToBed,
      'sleepWakeUpTime': ?sleepWakeUpTime,
    };

void main() {
  group('rolling workload math (backend/utils/metrics.js port)', () {
    // 8 contiguous days, 2026-07-10 .. 2026-07-17, day loads:
    //   [100, 200, 0, 300, 100, 0, 0, 400]
    // Zero days (12th, 15th, 16th) have NO session — the day grid must
    // synthesize them.
    final sessions = [
      session('2026-07-10T09:00:00', totalLoad: 100),
      session('2026-07-11T09:00:00', totalLoad: 200),
      session('2026-07-13T09:00:00', totalLoad: 300),
      session('2026-07-14T09:00:00', totalLoad: 100),
      session('2026-07-17T09:00:00', totalLoad: 400),
    ];
    final m = AthleteMetricsService.computeFromSessions(
      sessions,
      now: DateTime(2026, 7, 17, 18),
    );

    test('contiguous day grid with zero-load days synthesized', () {
      expect(m.total.length, 8);
      expect(m.total.first.d, '10/07');
      expect(m.total.last.d, '17/07');
      expect(m.total.map((p) => p.load).toList(),
          [100, 200, 0, 300, 100, 0, 0, 400]);
      for (var i = 0; i < 8; i++) {
        expect(m.total[i].date, DateTime(2026, 7, 10 + i));
      }
    });

    test('acute = trailing-7-day sum / 7', () {
      // day 1 (i=0): window {100}                       → 100/7 = 14.285714…
      expect(m.total[0].acute, closeTo(100 / 7, 1e-9));
      // day 7 (i=6): window days 0..6
      //   100+200+0+300+100+0+0 = 700                   → 700/7 = 100
      expect(m.total[6].acute, closeTo(100.0, 1e-9));
      // day 8 (i=7): window days 1..7 (day 0 drops out)
      //   200+0+300+100+0+0+400 = 1000                  → 1000/7 = 142.857142…
      expect(m.total[7].acute, closeTo(1000 / 7, 1e-9));
    });

    test('chronic = EWMA of acute, λ = 2/29, seeded from day-0 acute', () {
      // λ = 2/29, 1−λ = 27/29. Acute series (from above):
      //   a = [100/7, 300/7, 300/7, 600/7, 100, 100, 100, 1000/7]
      // c0 = a0 = 100/7 = 14.285714286
      expect(m.total[0].chronic, closeTo(100 / 7, 1e-9));
      // c1 = a1·λ + c0·(1−λ) = (300/7)(2/29) + (100/7)(27/29)
      //    = (600 + 2700)/203 = 3300/203 = 16.256157635
      expect(m.total[1].chronic, closeTo(3300 / 203, 1e-9));
      // c2 = a2·λ + c1·(1−λ) = 600/203 + (3300/203)(27/29)
      //    = (600·29 + 3300·27)/5887 = (17400 + 89100)/5887
      //    = 106500/5887 = 18.090708340
      expect(m.total[2].chronic, closeTo(106500 / 5887, 1e-9));
      // Continuing the recurrence numerically:
      // c3 = (600/7)(2/29) + c2(27/29) = 5.911330049 + 16.843073283 = 22.754403332
      // c4 = 100(2/29) + c3(27/29)    = 6.896551724 + 21.184961584 = 28.081685861
      // c5 = 6.896551724 + c4(27/29)  = 6.896551724 + 26.145017870 = 33.041569594
      // c6 = 6.896551724 + c5(27/29)  = 6.896551724 + 30.762840656 = 37.659392381
      // c7 = (1000/7)(2/29) + c6(27/29)
      //    = 9.852216749 + 35.062192906 = 44.914409655
      expect(m.total[7].chronic, closeTo(44.91440965513634, 1e-9));
    });

    test('acwr = acute / chronic', () {
      // Day 0: acute == chronic (seed) → exactly 1.
      expect(m.total[0].acwr, closeTo(1.0, 1e-12));
      // Day 7: (1000/7) / 44.914409655 = 142.857142857 / 44.914409655
      //      = 3.180652801
      expect(m.total[7].acwr, closeTo(3.1806528006052943, 1e-9));
    });

    test('z_last = (load_last − chronic_last) / population σ of all day loads',
        () {
      // Day 0: only one load seen → σ = 0 → z defined as 0.
      expect(m.total[0].z, 0.0);
      // All 8 day loads (zeros included): mean = 1100/8 = 137.5
      // Squared deviations:
      //   (100−137.5)² = 1406.25    (200−137.5)² =  3906.25
      //   (0−137.5)²   = 18906.25   (300−137.5)² = 26406.25
      //   (100−137.5)² = 1406.25    (0−137.5)²   = 18906.25
      //   (0−137.5)²   = 18906.25   (400−137.5)² = 68906.25
      // Σ = 158750 → population variance = 158750/8 = 19843.75
      // σ = √19843.75 = 140.867845870
      // z = (400 − 44.914409655) / 140.867845870
      //   = 355.085590345 / 140.867845870 = 2.520700080
      expect(m.total[7].z, closeTo(2.5207000799390267, 1e-9));
    });

    test('loadTargets band = chronic × 0.8 .. chronic × 1.3', () {
      final t = m.loadTargets().total;
      // chronic_7 = 44.914409655 (above)
      // low  = 0.8 × 44.914409655 = 35.931527724
      // high = 1.3 × 44.914409655 = 58.388732552
      expect(t.chronic, closeTo(44.91440965513634, 1e-9));
      expect(t.low, closeTo(35.93152772410907, 1e-9));
      expect(t.high, closeTo(58.38873255167724, 1e-9));
    });
  });

  group('day-grid gap handling', () {
    test('a 5-day gap up to today yields a 6-day series with zero middles', () {
      final m = AthleteMetricsService.computeFromSessions(
        [
          session('2026-07-17T09:00:00', totalLoad: 50),
          session('2026-07-22T08:30:00', totalLoad: 70),
        ],
        now: DateTime(2026, 7, 22, 12),
      );
      expect(m.total.length, 6); // 17,18,19,20,21,22 July
      expect(m.total.map((p) => p.load).toList(), [50, 0, 0, 0, 0, 70]);
      expect(m.total.first.d, '17/07');
      expect(m.total.last.d, '22/07');
      for (var i = 0; i < 6; i++) {
        expect(m.total[i].date, DateTime(2026, 7, 17 + i));
      }
      // Last acute: window covers all 6 days (i−6 clamps to 0):
      //   (50+0+0+0+0+70)/7 = 120/7 = 17.142857143
      expect(m.total.last.acute, closeTo(120 / 7, 1e-9));
    });
  });

  group('stream grouping', () {
    test('train = primary+secondary, skill = skillLoad; same-day sessions sum',
        () {
      final m = AthleteMetricsService.computeFromSessions(
        [
          session('2026-07-21T08:00:00',
              primaryLoad: 30, secondaryLoad: 20, skillLoad: 10, totalLoad: 60),
          session('2026-07-21T17:00:00',
              primaryLoad: 5, secondaryLoad: 0, skillLoad: 15, totalLoad: 20),
        ],
        now: DateTime(2026, 7, 21, 20),
      );
      expect(m.train.length, 1);
      expect(m.skill.length, 1);
      expect(m.total.length, 1);
      // train = (30+20) + (5+0) = 55, skill = 10+15 = 25, total = 60+20 = 80
      expect(m.train.single.load, 55);
      expect(m.skill.single.load, 25);
      expect(m.total.single.load, 80);
      // Single-day series: chronic seeds from acute, so acwr is exactly 1 and
      // σ of one sample is 0 → z = 0.
      expect(m.total.single.acwr, 1.0);
      expect(m.total.single.z, 0.0);
    });
  });

  group('recovery points', () {
    final m = AthleteMetricsService.computeFromSessions(
      [
        // Check-in with two of four scores → missing ones default to 3.
        session('2026-07-19T08:00:00', totalLoad: 100, sleep: 2, wellness: 4),
        // Load-only day: no wellness fields → no recovery point.
        session('2026-07-20T08:00:00', totalLoad: 50),
        // Full check-in, best possible scores.
        session('2026-07-21T08:00:00',
            sleep: 1, wellness: 1, soreness: 1, fatigue: 1),
      ],
      now: DateTime(2026, 7, 21, 12),
    );

    test('only days with wellness fields produce points', () {
      expect(m.recovery.length, 2);
      expect(m.recovery[0].date, DateTime(2026, 7, 19));
      expect(m.recovery[1].date, DateTime(2026, 7, 21));
      expect(m.total.length, 3); // the load grid still spans 19..21
    });

    test('missing individual scores default to 3 (neutral)', () {
      expect(m.recovery[0].sleep, 2);
      expect(m.recovery[0].wellness, 4);
      expect(m.recovery[0].soreness, 3);
      expect(m.recovery[0].fatigue, 3);
    });

    test('readinessPct matches the backend readinessPercent formula', () {
      // Backend: ((5−sl)+(5−wl)+(5−so)+(5−fa))/16, defaults 3.
      // Point 0: ((5−2)+(5−4)+(5−3)+(5−3))/16 = (3+1+2+2)/16 = 8/16 = 0.5
      // App form: (5 − (2+4+3+3)/4)/4 = (5 − 3)/4 = 0.5   — identical.
      expect(m.recovery[0].readinessPct, closeTo(0.5, 1e-12));
      // Point 1: (5 − (1+1+1+1)/4)/4 = (5 − 1)/4 = 1.0
      expect(m.recovery[1].readinessPct, closeTo(1.0, 1e-12));
    });
  });

  group('sleep nights', () {
    test('kept only when both bed and wake times parse as HH:MM', () {
      final m = AthleteMetricsService.computeFromSessions(
        [
          // No colon in bed time → malformed → skipped.
          session('2026-07-18T08:00:00',
              sleepTimeToBed: '2230', sleepWakeUpTime: '06:00'),
          // Valid pair → kept.
          session('2026-07-19T08:00:00',
              sleepTimeToBed: '22:30', sleepWakeUpTime: '06:15'),
          // Hour 25 / minute 99 out of range → skipped.
          session('2026-07-20T08:00:00',
              sleepTimeToBed: '25:99', sleepWakeUpTime: '06:00'),
          // Wake time missing → skipped.
          session('2026-07-21T08:00:00', sleepTimeToBed: '22:00'),
        ],
        now: DateTime(2026, 7, 21, 12),
      );
      expect(m.sleep.length, 1);
      final night = m.sleep.single;
      expect(night.d, '19/07');
      // 22:30 → 22·60+30 = 1350 minutes; 06:15 → 6·60+15 = 375 minutes.
      expect(night.timeToBed, 1350);
      expect(night.wokeUp, 375);
      // Latency is not logged, so fell-asleep == bedtime.
      expect(night.fellAsleep, 1350);
      // Sleep time wraps midnight: (375 − 1350) mod 1440 = 465 min = 7h45m.
      expect(night.sleepMinutes, 465);
    });
  });

  group('empty input', () {
    test('no sessions → AthleteMetrics.empty', () {
      final m = AthleteMetricsService.computeFromSessions(
        const [],
        now: DateTime(2026, 7, 22),
      );
      expect(m.train, isEmpty);
      expect(m.skill, isEmpty);
      expect(m.total, isEmpty);
      expect(m.recovery, isEmpty);
      expect(m.sleep, isEmpty);
      expect(m.hasLoadData, isFalse);
      expect(m.hasRecoveryData, isFalse);
      expect(m.hasData, isFalse);
    });

    test('sessions with unparseable dates are ignored', () {
      final m = AthleteMetricsService.computeFromSessions(
        [
          <String, dynamic>{'date': 'not-a-date', 'totalLoad': 100},
          <String, dynamic>{'totalLoad': 200}, // no date at all
        ],
        now: DateTime(2026, 7, 22),
      );
      expect(m.hasData, isFalse);
      expect(m.total, isEmpty);
    });

    test('homeMetrics() on empty does not throw and returns the idle state',
        () {
      final h = AthleteMetrics.empty.homeMetrics();
      expect(h.performancePct, 0.0);
      expect(h.recoveryPct, 0.0);
      expect(h.todayExertion, 0.0); // nothing logged today reads 0, not the floor
      expect(h.performanceTrend, isEmpty);
    });
  });

  group('homeMetrics ring math', () {
    // Three consecutive days, check-in AND load every day, last one "today":
    //   20/07: load 100, scores all 2 → readiness (5−2)/4 = 0.75
    //   21/07: load 200, scores all 4 → readiness (5−4)/4 = 0.25
    //   22/07: load 150, scores all 3 → readiness (5−3)/4 = 0.50
    final m = AthleteMetricsService.computeFromSessions(
      [
        session('2026-07-20T08:00:00',
            totalLoad: 100, sleep: 2, wellness: 2, soreness: 2, fatigue: 2),
        session('2026-07-21T08:00:00',
            totalLoad: 200, sleep: 4, wellness: 4, soreness: 4, fatigue: 4),
        session('2026-07-22T08:00:00',
            totalLoad: 150, sleep: 3, wellness: 3, soreness: 3, fatigue: 3),
      ],
      now: DateTime(2026, 7, 22, 12),
    );
    final h = m.homeMetrics();

    test('recoveryPct = mean readiness of the last ≤7 check-ins', () {
      // (0.75 + 0.25 + 0.50)/3 = 1.5/3 = 0.5
      expect(h.recoveryPct, closeTo(0.5, 1e-12));
    });

    test('performancePct = 0.6·readiness + 0.4·loadBalance(latest acwr)', () {
      // Day loads [100, 200, 150]:
      //   a0 = 100/7, a1 = 300/7, a2 = 450/7
      //   c0 = 100/7
      //   c1 = (300/7)(2/29) + (100/7)(27/29) = 3300/203
      //   c2 = (450/7)(2/29) + (3300/203)(27/29)
      //      = (26100 + 89100)/5887 = 115200/5887 = 19.568540853
      //   acwr_2 = (450/7)/(115200/5887) = 2649150/806400 = 3.28515625
      expect(m.total.last.acwr, closeTo(3.28515625, 1e-9));
      // loadBalance(3.28515625) = 1 − |3.28515625 − 1.05|/1.05
      //   = 1 − 2.23515625/1.05 = 1 − 2.128720238 → clamps to 0
      // performance = 0.6·0.5 + 0.4·0 = 0.3
      expect(h.performancePct, closeTo(0.3, 1e-9));
    });

    test('todayExertion = exertion of the latest daily total', () {
      // exertion(150) = 2.087·ln(150/50 + 1) + 2 = 2.087·ln 4 + 2
      //   = 2.087 × 1.386294361 + 2 = 2.893196332 + 2 = 4.893196332
      expect(h.todayExertion, closeTo(4.893196331657212, 1e-9));
    });

    test('trend is the rolling composite; last element equals the ring', () {
      // Per check-in day, r = mean readiness of the trailing ≤7 check-ins,
      // acwr = that day's total-series acwr:
      //   20/07: r = 0.75, acwr_0 = a0/c0 = 1 (seed)
      //          loadBalance(1) = 1 − 0.05/1.05 = 0.952380952
      //          comp = 0.6·0.75 + 0.4·0.952380952
      //               = 0.45 + 0.380952381 = 0.830952381 → ×100 → 83
      //   21/07: r = (0.75+0.25)/2 = 0.5
      //          acwr_1 = (300/7)/(3300/203) = 29/11 = 2.636363636
      //          loadBalance = 1 − 1.586363636/1.05 < 0 → 0
      //          comp = 0.6·0.5 = 0.3 → 30
      //   22/07: r = (0.75+0.25+0.5)/3 = 0.5, acwr_2 = 3.28515625 → lb 0
      //          comp = 0.3 → 30
      expect(h.performanceTrend, [83.0, 30.0, 30.0]);
      // The last trend point must be the ring value: performancePct×100
      // rounded = round(30.0) = 30.
      expect(h.performanceTrend.last,
          (h.performancePct * 100).roundToDouble());
    });
  });

  group('pure helper functions (backend parity)', () {
    test('loadBalance peaks at 1.05 and clamps to [0,1]', () {
      expect(loadBalance(1.05), 1.0);
      // 1 − |0.525 − 1.05|/1.05 = 1 − 0.525/1.05 = 1 − 0.5 = 0.5
      expect(loadBalance(0.525), closeTo(0.5, 1e-12));
      // 1 − |0 − 1.05|/1.05 = 0 exactly at acwr 0
      expect(loadBalance(0.0), closeTo(0.0, 1e-12));
      // 1 − |2.1 − 1.05|/1.05 = 0; anything further clamps at 0
      expect(loadBalance(3.0), 0.0);
    });

    test('compositePerformance = 0.6·readiness + 0.4·balance, clamped', () {
      expect(compositePerformance(1.0, 1.05), 1.0);
      // 0.6·0.5 + 0.4·0 = 0.3
      expect(compositePerformance(0.5, 0.0), closeTo(0.3, 1e-12));
    });

    test('WorkPoint.exertion matches backend exertion()', () {
      WorkPoint wp(double load) => WorkPoint(
          d: '01/07',
          date: DateTime(2026, 7, 1),
          load: load,
          acute: 0,
          chronic: 0,
          acwr: 0,
          z: 0);
      // Zero load floors at 2 (backend: l > 0 ? … : 2).
      expect(wp(0).exertion, 2.0);
      // exertion(100) = 2.087·ln(100/50 + 1) + 2 = 2.087·ln 3 + 2
      //   = 2.087 × 1.098612289 + 2 = 2.292803846 + 2 = 4.292803846
      expect(wp(100).exertion, closeTo(4.292803846450345, 1e-9));
      // Huge loads cap at 10.
      expect(wp(1e9).exertion, 10.0);
    });
  });
}
