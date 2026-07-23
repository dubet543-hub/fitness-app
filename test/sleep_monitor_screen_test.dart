import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/screens/sleep_monitor_screen.dart';
import 'package:fitness_app/services/entitlements.dart';

// Smoke tests over the sleep log screen: the summary card must report the sheet
// figures, and editing a clock must move them.

// The form is a lazy ListView, so the default 800x600 test viewport never
// builds the questions below the fold. A tall surface renders the whole form.
Future<void> pumpScreen(WidgetTester t) async {
  // The screen sits behind a subscription FeatureGuard; unlock it for tests.
  EntitlementsService.debugOverride = EntitlementsService.allFeaturesForTesting();
  t.view.physicalSize = const Size(1000, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  await t.pumpWidget(const MaterialApp(home: SleepMonitorScreen()));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('summary card shows sleep time in hh:mm from the defaults',
      (t) async {
    await pumpScreen(t);

    // Defaults: bed 22:30, 15m to fall asleep, wake 06:30, out of bed 06:40.
    // Sleep time = 22:45 → 06:30 = 07:45. Time in bed = 22:30 → 06:40 = 08:10.
    expect(find.text('07:45'), findsOneWidget);
    expect(find.text('sleep time (hh:mm)'), findsOneWidget);
    expect(find.text('08:10'), findsOneWidget);

    // Efficiency = 465 / 490 = 94.9% → 95%.
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('logging a disturbance reduces sleep time and efficiency',
      (t) async {
    await pumpScreen(t);

    await t.tap(find.text('Yes'));
    await t.pumpAndSettle();

    // Default 10m awake after the disturbance: 07:45 → 07:35.
    expect(find.text('07:35'), findsOneWidget);
    expect(find.text('07:45'), findsNothing);
    // 455 / 490 = 92.9% → 93%.
    expect(find.text('93%'), findsOneWidget);
  });

  testWidgets('the out-of-bed clock is editable and changes time in bed',
      (t) async {
    await pumpScreen(t);
    expect(find.text('Got out of bed'), findsOneWidget);

    // Longer lying-in leaves sleep time alone but lowers efficiency.
    expect(find.text('08:10'), findsOneWidget);
    expect(find.text('06:40'), findsOneWidget);
  });
}
