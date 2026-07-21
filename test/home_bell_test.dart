import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/screens/home_tab.dart';
import 'package:fitness_app/screens/notifications_page.dart';

void main() {
  testWidgets('the app-bar bell opens the notifications page', (t) async {
    SharedPreferences.setMockInitialValues({});

    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      home: HomeTab(
        name: 'ATS-2025-001',
        email: 'athlete1@test.com',
        photoUrl: null,
        onLogout: () {},
        onOpenProfile: () {},
      ),
    ));
    // HomeTab runs a looping animation, so pumpAndSettle never returns —
    // pump fixed frames instead.
    await t.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationsPage), findsNothing);

    await t.tap(find.byIcon(Icons.notifications_outlined));
    await t.pump();                                    // start the route push
    await t.pump(const Duration(milliseconds: 600));   // finish the transition

    expect(find.byType(NotificationsPage), findsOneWidget);
  });
}
