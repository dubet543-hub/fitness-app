import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/screens/home_tab.dart';

Future<void> pumpHome(WidgetTester t) async {
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
  // HomeTab animates forever; pump fixed frames rather than settling.
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('alarm defaults to 8:30 and reads back a saved time', (t) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(t);
    expect(find.text('8:30'), findsOneWidget);
    expect(find.text('ALARM ON'), findsOneWidget);
  });

  testWidgets('a persisted alarm time is restored on launch', (t) async {
    SharedPreferences.setMockInitialValues({
      'wake_alarm_hour': 6,
      'wake_alarm_minute': 5,
      'wake_alarm_on': true,
    });
    await pumpHome(t);
    expect(find.text('6:05'), findsOneWidget);
    expect(find.text('8:30'), findsNothing);
  });

  testWidgets('tapping the pip disarms the alarm and saves that', (t) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(t);

    await t.tap(find.text('ALARM ON'));
    await t.pump(const Duration(milliseconds: 100));

    expect(find.text('ALARM OFF'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('wake_alarm_on'), false);
  });

  testWidgets('a disarmed alarm stays off across a relaunch', (t) async {
    SharedPreferences.setMockInitialValues({
      'wake_alarm_hour': 8,
      'wake_alarm_minute': 30,
      'wake_alarm_on': false,
    });
    await pumpHome(t);
    expect(find.text('ALARM OFF'), findsOneWidget);
  });
}
