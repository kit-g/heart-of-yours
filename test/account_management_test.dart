// Coverage for lib/presentation/routes/settings/account.dart: account
// management from Settings for a signed-in, non-anonymous user — reset
// password, change name, and account deletion (with the password
// confirmation an account made with one gets, and the destructive call only
// landing after it).
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart' show InternalUserInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// An account made with a password: the one provider [AccountManagementPage]
/// checks for (`Auth.hasPassword`) to decide whether deletion asks for one.
MockUser _passwordAccount({String uid = 'u1', String email = 'u1@test', String? displayName}) {
  return MockUser(
    uid: uid,
    email: email,
    displayName: displayName,
    providerData: [
      fb.UserInfo.fromPigeon(
        InternalUserInfo(email: email, uid: uid, providerId: 'password', isAnonymous: false, isEmailVerified: true),
      ),
    ],
  );
}

/// An account with no password provider at all (Apple/Google) — deletion
/// skips the password prompt for these.
MockUser _providerAccount({String uid = 'u1', String email = 'u1@test'}) {
  return MockUser(
    uid: uid,
    email: email,
    providerData: [
      fb.UserInfo.fromPigeon(
        InternalUserInfo(email: email, uid: uid, providerId: 'google.com', isAnonymous: false, isEmailVerified: true),
      ),
    ],
  );
}

/// Reauthentication succeeds by default (see [MockUser.reauthenticateWithCredential]);
/// this double refuses it instead, the way a wrong password really would.
class _WrongPasswordFirebase extends MockFirebaseAuth {
  new({required MockUser mockUser}) : super(signedIn: true, mockUser: mockUser);
}

// ignore: must_be_immutable — MockUser's own fields are mutable; nothing here adds one
class _WrongPasswordUser extends MockUser {
  new(MockUser base) : super(uid: base.uid, email: base.email, providerData: base.providerData);

  @override
  Future<fb.UserCredential> reauthenticateWithCredential(fb.AuthCredential? credential) async {
    throw fb.FirebaseAuthException(code: 'wrong-password');
  }
}

/// A device offline for the reset-password request.
class _OfflineFirebase extends MockFirebaseAuth {
  new({required MockUser mockUser}) : super(signedIn: true, mockUser: mockUser);

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

  Future<void> pumpToAccountManagement(WidgetTester tester, {required MockFirebaseAuth firebase}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await harness.pumpHeartApp(tester, db: db, api: api, cdn: cdn, firebaseAuth: firebase, settle: false);
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.text('Account control'));
    await tester.pumpTimes();
    expect(find.byType(AccountManagementPage), findsOneWidget);
  }

  group('reset password', () {
    testWidgets('sends the reset link to the signed-in email on confirmation', (tester) async {
      final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
      await pumpToAccountManagement(tester, firebase: firebase);

      await tester.tap(find.text('Reset password'));
      await tester.pumpTimes();
      expect(find.text('Reset password', skipOffstage: false), findsWidgets);

      await tester.tap(find.text('OK'));
      await tester.pumpTimes();

      expect(find.textContaining('password setup email is on its way'), findsOneWidget);
    });

    testWidgets('a network failure is reported instead of a false confirmation', (tester) async {
      final firebase = _OfflineFirebase(mockUser: _passwordAccount());
      await pumpToAccountManagement(tester, firebase: firebase);

      await tester.tap(find.text('Reset password'));
      await tester.pumpTimes();
      await tester.tap(find.text('OK'));
      await tester.pumpTimes();

      expect(find.textContaining('The internet tripped over a dumbbell'), findsOneWidget);
    });
  });

  testWidgets('changing the name saves through Auth once the check is tapped', (tester) async {
    final firebase = MockFirebaseAuth(mockUser: _passwordAccount(displayName: 'Old Name'), signedIn: true);
    await pumpToAccountManagement(tester, firebase: firebase);

    await tester.enterTextAndWait(find.byType(TextField).first, 'New Name');
    await tester.pumpTimes();
    await tester.tap(find.byIcon(Icons.check_circle_rounded));
    await tester.pumpTimes();

    expect(firebase.currentUser?.displayName, 'New Name');
  });

  group('account deletion', () {
    testWidgets('an account made with a password is asked for it, and only then is it deleted', (tester) async {
      final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
      await pumpToAccountManagement(tester, firebase: firebase);

      await tester.tap(find.text('Delete account'));
      await tester.pumpTimes();
      expect(find.text('Are you sure you want to delete your account?'), findsOneWidget);

      await tester.tap(find.text('Yep, go on without me!'));
      await tester.pumpTimes();

      // Has a password, so the password prompt is next rather than an
      // immediate deletion.
      expect(find.text('Confirm your account deletion'), findsOneWidget);
      verifyNever(api.deleteAccount(accountId: anyNamed('accountId'), appleGrant: anyNamed('appleGrant')));

      await tester.enterTextAndWait(find.byType(TextField).last, 'correct-horse');
      await tester.tap(find.text('Farewell!'));
      await tester.pumpTimes();

      // The destructive call itself, and only after both confirmations. What
      // follows it (`Auth._logout`) always signs out of Google too, even for
      // a password account — real `GoogleSignIn`, which this harness has no
      // platform channel for — so the page navigating away on success is not
      // asserted here (see the HANDOFF for this gap).
      verify(api.deleteAccount(accountId: 'u1', appleGrant: null)).called(1);
    });

    testWidgets('a deleted account leaves nothing of itself in memory for the session after it', (tester) async {
      final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
      await pumpToAccountManagement(tester, firebase: firebase);
      final workouts = Workouts.of(tester.element(find.byType(AccountManagementPage)));
      expect(workouts.userId, 'u1');

      await tester.tap(find.text('Delete account'));
      await tester.pumpTimes();
      await tester.tap(find.text('Yep, go on without me!'));
      await tester.pumpTimes();
      await tester.enterTextAndWait(find.byType(TextField).last, 'correct-horse');
      await tester.tap(find.text('Farewell!'));
      await tester.pumpTimes();

      verify(api.deleteAccount(accountId: 'u1', appleGrant: null)).called(1);
      // cleared before the sign-out, as the profile's log-out does
      expect(workouts.userId, isNull);
    });

    testWidgets('cancelling the first confirmation deletes nothing', (tester) async {
      final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
      await pumpToAccountManagement(tester, firebase: firebase);

      await tester.tap(find.text('Delete account'));
      await tester.pumpTimes();
      await tester.tap(find.text('Oh no, I like it here!'));
      await tester.pumpTimes();

      expect(find.byType(AccountManagementPage), findsOneWidget);
      verifyNever(api.deleteAccount(accountId: anyNamed('accountId'), appleGrant: anyNamed('appleGrant')));
    });

    testWidgets('a provider account (no password) skips straight past the password prompt', (tester) async {
      // A Google/Apple account re-authenticates through its own provider sheet
      // rather than a password prompt — asking one of these for a password it
      // never set is the bug #`hasPassword` exists to avoid. The provider
      // sheet itself needs a real platform channel this harness does not
      // have, so this only asserts the *routing*: the branch that would ask
      // for a password never runs.
      final firebase = MockFirebaseAuth(mockUser: _providerAccount(), signedIn: true);
      await pumpToAccountManagement(tester, firebase: firebase);

      await tester.tap(find.text('Delete account'));
      await tester.pumpTimes();
      await tester.tap(find.text('Yep, go on without me!'));
      await tester.pumpTimes();

      expect(find.text('Confirm your account deletion'), findsNothing);
    });

    testWidgets('a wrong password refuses the deletion and reports invalid credentials', (tester) async {
      final base = _passwordAccount();
      final firebase = _WrongPasswordFirebase(mockUser: _WrongPasswordUser(base));
      await pumpToAccountManagement(tester, firebase: firebase);

      await tester.tap(find.text('Delete account'));
      await tester.pumpTimes();
      await tester.tap(find.text('Yep, go on without me!'));
      await tester.pumpTimes();
      await tester.enterTextAndWait(find.byType(TextField).last, 'wrong-password');
      await tester.tap(find.text('Farewell!'));
      await tester.pumpTimes();

      expect(find.textContaining("Well, that didn't work"), findsOneWidget);
      verifyNever(api.deleteAccount(accountId: anyNamed('accountId'), appleGrant: anyNamed('appleGrant')));
      expect(find.byType(AccountManagementPage), findsOneWidget);
    });
  });
}
