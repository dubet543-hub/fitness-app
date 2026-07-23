import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/screens/legal_pages.dart';
import 'package:fitness_app/screens/login_screen.dart';
import 'package:fitness_app/services/local_log_store.dart';
import 'package:fitness_app/widgets/legal_consent.dart';

/// Sign-in is gated on accepting the Terms & Privacy Policy, and that
/// acceptance is asked for exactly once per [kLegalVersion].
void main() {
  Widget app({required void Function() onSignIn}) => MaterialApp(
    home: LoginScreen(
      onEmailSignIn: (email, password) async => onSignIn(),
    ),
  );

  /// The sign-in card is taller than the default 800×600 test window, which
  /// would push the consent boxes out of the hit-testable area.
  void useTallScreen(WidgetTester t) {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> fillCredentials(WidgetTester t) async {
    await t.enterText(find.byType(TextField).first, 'athlete1@test.com');
    await t.enterText(find.byType(TextField).at(1), 'hunter2');
  }

  /// Taps the tick box itself rather than the label — the label carries the
  /// Terms/Privacy links, which would navigate instead of toggling.
  Future<void> tapTick(WidgetTester t, Type checkbox) async {
    await t.tap(find.descendant(
      of: find.byType(checkbox),
      matching: find.byType(AnimatedContainer),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('sign-in is blocked until the agreement box is ticked', (t) async {
    SharedPreferences.setMockInitialValues({});
    useTallScreen(t);
    var signedIn = false;

    await t.pumpWidget(app(onSignIn: () => signedIn = true));
    await t.pumpAndSettle();
    await fillCredentials(t);

    await t.tap(find.text('Sign In'));
    await t.pumpAndSettle();
    expect(signedIn, isFalse, reason: 'unaccepted terms must block sign-in');

    await tapTick(t, LegalAgreementCheckbox);
    await t.tap(find.text('Sign In'));
    await t.pumpAndSettle();

    expect(signedIn, isTrue);
    expect(await LocalLogStore.hasAcceptedLegal(kLegalVersion), isTrue);
  });

  testWidgets('acceptance is one-time — the box is not asked for again', (t) async {
    SharedPreferences.setMockInitialValues({});
    useTallScreen(t);
    await LocalLogStore.setLegalAccepted(kLegalVersion);
    var signedIn = false;

    await t.pumpWidget(app(onSignIn: () => signedIn = true));
    await t.pumpAndSettle();

    expect(find.byType(LegalAgreementCheckbox), findsNothing);
    expect(find.byType(LegalAcceptedNotice), findsOneWidget);

    await fillCredentials(t);
    await t.tap(find.text('Sign In'));
    await t.pumpAndSettle();
    expect(signedIn, isTrue);
  });

  testWidgets('tracking of metrics, sleep & fatigue needs its own opt-in', (t) async {
    SharedPreferences.setMockInitialValues({});
    useTallScreen(t);
    expect(await LocalLogStore.dailyLogsConsent(), isFalse,
        reason: 'consent is explicit, never a default');

    await t.pumpWidget(app(onSignIn: () {}));
    await t.pumpAndSettle();
    await fillCredentials(t);

    await tapTick(t, LegalAgreementCheckbox);
    await tapTick(t, TrackingConsentCheckbox);
    await t.tap(find.text('Sign In'));
    await t.pumpAndSettle();

    expect(await LocalLogStore.dailyLogsConsent(), isTrue);
  });
}
