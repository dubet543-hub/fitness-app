import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/services/entitlements.dart';
import 'package:fitness_app/widgets/feature_gate.dart';

/// Plan gating: a FeatureGuard must render its child only when the athlete's
/// plan includes the feature, and must lock — not crash, not leak content —
/// in every other state.
void main() {
  tearDown(() => EntitlementsService.debugOverride = null);

  Entitlements basePlan() => const Entitlements(
        status: 'active', plan: 'athlete_optimisation', planName: 'Athlete Optimisation',
        features: {
          FeatureKeys.workloadMonitoring, FeatureKeys.recovery,
          FeatureKeys.loadModulation, FeatureKeys.bodyComposition,
        },
        expiresAt: null, trialEndsAt: null, graceEndsAt: null,
        complimentary: false, plans: [], featureNames: {},
      );

  testWidgets('included feature renders its screen', (t) async {
    EntitlementsService.debugOverride = basePlan();
    await t.pumpWidget(const MaterialApp(
      home: FeatureGuard(feature: FeatureKeys.recovery, child: Text('UNLOCKED')),
    ));
    await t.pumpAndSettle();
    expect(find.text('UNLOCKED'), findsOneWidget);
  });

  testWidgets('feature outside the plan shows the lock, not the screen', (t) async {
    EntitlementsService.debugOverride = basePlan();
    await t.pumpWidget(const MaterialApp(
      home: FeatureGuard(feature: FeatureKeys.bowling, child: Text('UNLOCKED')),
    ));
    await t.pumpAndSettle();
    expect(find.text('UNLOCKED'), findsNothing);
    expect(find.textContaining('is locked'), findsOneWidget);
    expect(find.text('View plans'), findsOneWidget);
  });

  testWidgets('trial unlocks everything', (t) async {
    EntitlementsService.debugOverride = EntitlementsService.allFeaturesForTesting();
    await t.pumpWidget(const MaterialApp(
      home: FeatureGuard(feature: FeatureKeys.bowling, child: Text('UNLOCKED')),
    ));
    await t.pumpAndSettle();
    expect(find.text('UNLOCKED'), findsOneWidget);
  });

  test('₹ uses Indian digit grouping', () {
    expect(formatInr(20000), '₹20,000');
    expect(formatInr(25000), '₹25,000');
    expect(formatInr(100000), '₹1,00,000');
    expect(formatInr(500), '₹500');
  });
}
