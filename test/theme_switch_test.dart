import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/core/theme.dart';
import 'package:fitness_app/navigation/main_shell.dart';
import 'package:fitness_app/screens/explore_tab.dart';
import 'package:fitness_app/screens/player_dashboard_screen.dart';

// Guards the light/dark switch. The palette in theme.dart is mutable globals
// read at build time, so a screen only re-colours if it genuinely rebuilds —
// a const tab constructor silently breaks that (Flutter skips identical
// widgets), which is what stranded Motion and Dashboard on the dark palette.

/// Mirrors main.dart: rebuild the app whenever the theme mode changes.
Widget themedApp() => ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, child) {
        applyBrightness(effectiveBrightness(mode));
        return MaterialApp(
          theme: buildAppTheme(),
          home: MainShell(
            name: 'ATS-2025-001',
            email: 'athlete1@test.com',
            photoUrl: null,
            onLogout: () {},
          ),
        );
      },
    );

/// Background colour the given tab is actually painting.
Color? tabBg(WidgetTester t, Type tab) {
  final scaffold = t.widget<Scaffold>(
    find.descendant(of: find.byType(tab), matching: find.byType(Scaffold)).first,
  );
  return scaffold.backgroundColor;
}

Future<void> selectTab(WidgetTester t, String label) async {
  // The nav bar uppercases its labels.
  await t.tap(find.text(label.toUpperCase()));
  await t.pump(const Duration(milliseconds: 500)); // tab animation
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appThemeMode.value = ThemeMode.dark;
    applyBrightness(Brightness.dark);
  });

  tearDown(() {
    appThemeMode.value = ThemeMode.dark;
    applyBrightness(Brightness.dark);
  });

  testWidgets('Motion and Dashboard re-colour when switching to light',
      (t) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(themedApp());
    await t.pump(const Duration(milliseconds: 300));

    await selectTab(t, 'Motion');
    final motionDark = tabBg(t, ExploreTab);
    await selectTab(t, 'Dashboard');
    final dashDark = tabBg(t, PlayerDashboardScreen);

    // Both start on the dark background.
    expect(motionDark, isNotNull);
    expect(motionDark, dashDark);

    // Flip to light, exactly as the Appearance page does.
    appThemeMode.value = ThemeMode.light;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    final dashLight = tabBg(t, PlayerDashboardScreen);
    await selectTab(t, 'Motion');
    final motionLight = tabBg(t, ExploreTab);

    expect(dashLight, isNot(dashDark),
        reason: 'Dashboard kept the dark background after switching to light');
    expect(motionLight, isNot(motionDark),
        reason: 'Motion kept the dark background after switching to light');

    // And they land on the actual light background, not some other colour.
    expect(dashLight, kBg);
    expect(motionLight, kBg);
  });

  testWidgets('the text theme follows brightness rather than pinning to dark',
      (t) async {
    applyBrightness(Brightness.dark);
    final darkBody = buildAppTheme().textTheme.bodyMedium?.color;

    applyBrightness(Brightness.light);
    final lightBody = buildAppTheme().textTheme.bodyMedium?.color;

    expect(darkBody, isNotNull);
    expect(lightBody, isNot(darkBody));
  });
}
