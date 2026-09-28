// Coverage for lib/presentation/routes/login/sign_up.dart: the sign-up form
// reached from a signed-out session (Profile's no-account dialog -> Login ->
// "Sign up"), submitting real credentials against a fake Firebase and
// asserting the resulting Auth call and error/validation states.
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart' show PasswordPolicy;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// An anonymous Firebase user that can be linked onto an account — the same
/// double `shared/heart_state/test/auth_test.dart` uses for the same reason:
/// the package's own [MockUser.linkWithCredential] hands the *same* (still
/// anonymous) user back, which trips [MockUserCredential]'s own assertion
/// that an anonymous credential wraps an anonymous user.
// ignore: must_be_immutable — MockUser's own fields are mutable; nothing here adds one
class _LinkableAnonymous extends MockUser {
  final MockFirebaseAuth auth;
  @override
  final String email;
  @override
  final String? displayName;

  new(this.auth, {this.email = 'new@test.com', this.displayName}) : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) {
    auth.mockUser = MockUser(uid: uid, email: email, displayName: displayName, isEmailVerified: false);
    return auth.signInWithCredential(credential);
  }
}

/// [MockFirebaseAuth] answers nothing for `validatePassword` (not overridden
/// by the package's own double, so it falls through to `noSuchMethod`) —
/// every one of these tests needs an answer, valid or not. The
/// `signInWithEmailAndPassword` override is the "log in instead" path's:
/// unlike `createUserWithEmailAndPassword`, the package's own version does not
/// set `mockUser` first, so the credential it wraps stays whatever the
/// anonymous session's still is — mismatched against the non-anonymous
/// `isAnonymous: false` it always signs in as.
class _Firebase extends MockFirebaseAuth {
  final fb.PasswordValidationStatus Function(String? password) validator;

  new({required this.validator}) : super(signedIn: false);

  @override
  Future<fb.PasswordValidationStatus> validatePassword(fb.FirebaseAuth auth, String? password) async {
    return validator(password);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    mockUser = MockUser(uid: 'acct-1', email: email);
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

fb.PasswordValidationStatus _validStatus(String? password) {
  return fb.PasswordValidationStatus(true, PasswordPolicy(const {}));
}

fb.PasswordValidationStatus _weakStatus(String? password) {
  final status = fb.PasswordValidationStatus(
    false,
    PasswordPolicy(const {
      'customStrengthOptions': {'minPasswordLength': 8, 'containsUppercaseCharacter': true},
    }),
  );
  status.meetsMinPasswordLength = false;
  status.meetsUppercaseRequirement = false;
  return status;
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

  /// Drives a signed-out launch to the sign-up form: the no-account dialog on
  /// an anonymous profile, its way to the login page, and the login page's
  /// own "Sign up" link — the same path a real user takes.
  Future<void> pumpToSignUp(WidgetTester tester, {required MockFirebaseAuth firebaseAuth}) async {
    // Phone-plausible surface: LayoutProvider only puts SignUpPage on its own
    // route (rather than a two-pane split) below its compact breakpoint.
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
    await tester.tap(find.text('Sign up'));
    await tester.pumpTimes();
    expect(find.byType(SignUpPage), findsOneWidget);
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Jane Doe',
    String email = 'new@test.com',
    String password = 'Str0ngPassw0rd',
  }) async {
    await tester.enterTextAndWait(find.byKey(AppKeys.loginName), name);
    await tester.enterTextAndWait(find.byKey(AppKeys.loginEmail), email);
    await tester.enterTextAndWait(find.byKey(AppKeys.loginPassword), password);
  }

  testWidgets('submitting valid credentials links the anonymous session onto the new account', (tester) async {
    final firebase = _Firebase(validator: _validStatus);
    firebase.mockUser = _LinkableAnonymous(firebase, email: 'new@test.com', displayName: 'Jane Doe');

    await pumpToSignUp(tester, firebaseAuth: firebase);
    await fillForm(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign up'));
    await tester.pumpTimes(10);

    // The uid survives the link; the session is no longer anonymous, and the
    // profile it lands back on is not the sign-up form.
    expect(firebase.currentUser?.uid, 'anon-1');
    expect(firebase.currentUser?.isAnonymous, isFalse);
    expect(firebase.currentUser?.email, 'new@test.com');
    expect(find.byType(SignUpPage), findsNothing);
  });

  testWidgets('a password that fails the policy shows what it is missing, and does not sign up', (tester) async {
    final firebase = _Firebase(validator: _weakStatus);
    firebase.mockUser = _LinkableAnonymous(firebase);

    await pumpToSignUp(tester, firebaseAuth: firebase);
    await fillForm(tester, password: 'weak');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign up'));
    await tester.pumpTimes(10);

    // Still anonymous: the create/link call is never reached.
    expect(firebase.currentUser?.isAnonymous, isTrue);
    expect(find.byType(SignUpPage), findsOneWidget);
    expect(find.byKey(const ValueKey('password_validation_status')), findsOneWidget);
    expect(find.text("Let's make a password that lifts:"), findsOneWidget);
  });

  testWidgets('an email already in use offers to log in instead, and does so on confirmation', (tester) async {
    final firebase = _Firebase(validator: _validStatus);
    firebase.mockUser = _TakenEmailAnonymous();

    await pumpToSignUp(tester, firebaseAuth: firebase);
    await fillForm(tester, email: 'existing@test.com');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign up'));
    await tester.pumpTimes(10);

    expect(find.text('Email already exists'), findsOneWidget);

    await tester.tap(find.text('Yes, sign me in!'));
    await tester.pumpTimes(10);

    // The confirmation logged in with the typed password instead of signing up.
    expect(firebase.signedInWithPassword, isTrue);
  });

  testWidgets('leaving every field empty just validates, without touching Firebase', (tester) async {
    final firebase = _Firebase(validator: _validStatus);
    firebase.mockUser = _LinkableAnonymous(firebase);

    await pumpToSignUp(tester, firebaseAuth: firebase);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign up'));
    await tester.pumpTimes();

    expect(find.text('Cannot be empty'), findsWidgets);
    expect(find.byType(SignUpPage), findsOneWidget);
    expect(firebase.currentUser?.isAnonymous, isTrue);
  });
}

/// An anonymous session whose credential already belongs to an account. Real
/// Firebase refuses a *link* onto a taken email with `credential-already-in-use`,
/// which `AuthExceptionReason.fromCode` has no mapping for — this double
/// throws the code the sign-up form actually keys `onEmailExists` on
/// (`email-already-in-use`), the same way it would arrive from
/// `createUserWithEmailAndPassword` for a non-anonymous sign-up.
// ignore: must_be_immutable — MockUser's own fields are mutable; nothing here adds one
class _TakenEmailAnonymous extends MockUser {
  new() : super(isAnonymous: true, uid: 'anon-1');

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) async {
    throw fb.FirebaseAuthException(code: 'email-already-in-use');
  }
}

extension on _Firebase {
  bool get signedInWithPassword => currentUser != null && !(currentUser!.isAnonymous);
}
