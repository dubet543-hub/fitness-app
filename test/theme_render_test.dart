import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/core/theme.dart';
import 'package:fitness_app/screens/player_stats_screen.dart';

// Renders the Dashboard in each theme so the light palette can be eyeballed.
// Regenerate with: flutter test --update-goldens test/theme_render_test.dart
void main() {
  for (final b in [Brightness.dark, Brightness.light]) {
    final name = b == Brightness.light ? 'light' : 'dark';
    testWidgets('dashboard recovery — $name', (t) async {
      SharedPreferences.setMockInitialValues({});
      applyBrightness(b);

      t.view.physicalSize = const Size(760, 2600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(() => applyBrightness(Brightness.dark));

      await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const PlayerStatsScreen(initialTab: 1),
      ));
      await t.pumpAndSettle();

      await expectLater(find.byType(PlayerStatsScreen),
          matchesGoldenFile('goldens/dashboard_$name.png'));
    });
  }
}
