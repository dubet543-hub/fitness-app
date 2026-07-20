import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/navigation/main_shell.dart';
import 'package:fitness_app/screens/home_tab.dart';
import 'package:fitness_app/widgets/common_widgets.dart';

void main() {
  testWidgets('tapping the home avatar selects the Profile tab', (t) async {
    SharedPreferences.setMockInitialValues({});

    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      home: MainShell(
        name: 'ATS-2025-001',
        email: 'athlete1@test.com',
        photoUrl: null,
        onLogout: () {},
      ),
    ));
    // HomeTab animates continuously, so pump fixed frames, never settle.
    await t.pump(const Duration(milliseconds: 300));

    // The shell keeps every tab alive in an IndexedStack, so presence alone
    // proves nothing — assert on which one is actually on top.
    expect(find.text('ACCOUNT'), findsNothing);

    final avatar = find.descendant(
      of: find.byType(HomeTab),
      matching: find.byType(AvatarWidget),
    );
    expect(avatar, findsOneWidget);

    await t.tap(avatar);
    await t.pump(const Duration(milliseconds: 400));

    // A Profile-only heading is now visible.
    expect(find.text('ACCOUNT'), findsOneWidget);
  });
}
