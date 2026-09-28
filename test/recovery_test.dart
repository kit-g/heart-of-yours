// Coverage for lib/presentation/routes/login/recovery.dart: the
// password-recovery form reached from Login's "Forgot password?" link,
// sending a real reset-email call against a fake Firebase and covering its
// error/validation/confirmation states.
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Records the address a reset was sent to, over the package's own working
/// `sendPasswordResetEmail` (unlike `validatePassword`, this one is actually
/// implemented on [MockFirebaseAuth]).
class _TrackingFirebase extends MockFirebaseAuth {
  String? lastEmail;

  new() : super(signedIn: false);

  @override
  Future<void> sendPasswordResetEmail({required String email, fb.ActionCodeSettings? actionCodeSettings}) {
    lastEmail = email;
    return super.sendPasswordResetEmail(email: email, actionCodeSettings: actionCodeSettings);
  }
}

/// A device that cannot reach the reset endpoint.
class _OfflineFirebase extends MockFirebaseAuth {
  new() : super(signedIn: false);

  @override
  Future<void> sendPasswordResetEmail({required String email, fb.ActionCodeSettings? actionCodeSettings}) async {
    throw fb.FirebaseAuthException(code: 'network-request-failed');
  }
}

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);
  });

  /// Drives a signed-out launch to the recovery form: the no-account dialog,
  /// login, and its own "Forgot password?" link.
  Future<void> pumpToRecovery(WidgetTester tester, {required MockFirebaseAuth firebaseAuth}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await harness.pumpHeartApp(tester, db: db, api: api, cdn: cdn, firebaseAuth: firebaseAuth, settle: false);
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.noAccount);
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.noAccountLogIn);
    await tester.pumpTimes();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpTimes();
    expect(find.byType(RecoveryPage), findsOneWidget);
  }

  testWidgets('sending a reset link calls Auth with the typed address and confirms', (tester) async {
    final firebase = _TrackingFirebase();
    await pumpToRecovery(tester, firebaseAuth: firebase);

    await tester.enterTextAndWait(find.byType(TextFormField), 'forgot@test.com');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpTimes(10);

    expect(firebase.lastEmail, 'forgot@test.com');
    expect(
      find.text(
        "If an account exists for this email, you'll receive a reset link shortly. Check your inbox and spam folder.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unreachable server shows a connectivity error, not a confirmation', (tester) async {
    final firebase = _OfflineFirebase();
    await pumpToRecovery(tester, firebaseAuth: firebase);

    await tester.enterTextAndWait(find.byType(TextFormField), 'forgot@test.com');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpTimes(10);

    expect(find.textContaining('The internet tripped over a dumbbell'), findsOneWidget);
  });

  testWidgets('the send button is disabled until an address is typed', (tester) async {
    final firebase = _TrackingFirebase();
    await pumpToRecovery(tester, firebaseAuth: firebase);

    final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Send Reset Link'));
    expect(button.onPressed, isNull);

    await tester.enterTextAndWait(find.byType(TextFormField), 'x');
    final enabled = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Send Reset Link'));
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('a whitespace-only address passes the emptiness check but is trimmed before it is sent', (tester) async {
    final firebase = _TrackingFirebase();
    await pumpToRecovery(tester, firebaseAuth: firebase);

    // Not `.isEmpty`, so the button enables and the form's validator (which
    // never trims) lets it through — only `_resetPassword` itself trims.
    await tester.enterTextAndWait(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpTimes(10);

    expect(firebase.lastEmail, '');
  });

  testWidgets('the wide layout leading back button reports the typed address rather than navigating a stack', (
    tester,
  ) async {
    String? reported;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: RecoveryPage(
          isWideScreen: true,
          address: 'existing@test.com',
          onLinkSent: (address) => reported = address,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump();

    expect(reported, 'existing@test.com');
  });
}
