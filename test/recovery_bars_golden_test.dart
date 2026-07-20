import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/screens/player_stats_screen.dart';

// Golden for the Recovery tab's metric bars. Regenerate with:
//   flutter test --update-goldens test/recovery_bars_golden_test.dart
// Bar length must step visibly per score point, tallest at 5.

void main() {
  testWidgets('recovery metric bars', (t) async {
    SharedPreferences.setMockInitialValues({});

    t.view.physicalSize = const Size(760, 1650);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(initialTab: 1),
    ));
    await t.pumpAndSettle();

    await expectLater(
      find.byType(PlayerStatsScreen),
      matchesGoldenFile('goldens/recovery_bars.png'),
    );
  });
}
