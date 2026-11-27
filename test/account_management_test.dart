// Coverage for lib/presentation/routes/settings/account.dart: account
// management from Settings for a signed-in, non-anonymous user — reset
// password, change name, and account deletion (with the password
// confirmation an account made with one gets, and the destructive call only
// landing after it).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart' show InternalUserInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart' show ChartPreference, Exercise, Goal, GoalStage, Thread, Workout;
import 'package:heart_state/heart_state.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
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

/// An account with two sign-ins, which is what makes Disconnect appear.
MockUser _twoProviderAccount({String uid = 'u1', String email = 'u1@test'}) {
  return MockUser(
    uid: uid,
    email: email,
    providerData: [
      for (final provider in ['google.com', 'password'])
        fb.UserInfo.fromPigeon(
          InternalUserInfo(email: email, uid: uid, providerId: provider, isAnonymous: false, isEmailVerified: true),
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

  Future<void> pumpToAccountManagement(
    WidgetTester tester, {
    required MockFirebaseAuth firebase,
    Map<String, Object> prefs = const {},
  }) async {
    if (prefs.isNotEmpty) SharedPreferences.setMockInitialValues({...pastOnboarding(), ...prefs});
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

    await tester.tap(find.text('Manage account'));
    await tester.pumpTimes();
    expect(find.byType(AccountManagementPage), findsOneWidget);
  }

  testWidgets('an account signed up without a name goes by its email in the profile, never "?"', (tester) async {
    final firebase = MockFirebaseAuth(mockUser: _passwordAccount(email: 'muffin@heart.test'), signedIn: true);
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await harness.pumpHeartApp(tester, db: db, api: api, cdn: cdn, firebaseAuth: firebase, settle: false);
    await tester.pumpTimes();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('muffin@heart.test'), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('a session that ends takes its token with it', (tester) async {
    // the next account's opening page must not dial out as this one (#363)
    final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
    await harness.pumpHeartApp(tester, db: db, api: api, cdn: cdn, firebaseAuth: firebase, settle: false);
    await tester.pumpTimes();
    // the restored account arriving is a change of hands too: from nobody
    verify(api.unauthenticate()).called(1);

    await firebase.signOut();
    await tester.pumpTimes();

    verify(api.unauthenticate()).called(greaterThanOrEqualTo(1));
  });

  // Ending on its own rather than through the app's log out (#671): Firebase
  // signs a user out by itself on a revoked or expired token or a deleted or
  // disabled account, and the server can report the account gone. The
  // anonymous session minted next starts empty, and the account's data,
  // kept on the device under its uid, is its own again when it signs back in.
  group('a session that ends on its own', () {
    final finished = Workout(name: 'Push');
    final going = Workout(name: 'Legs');
    final goal = Goal(
      id: 'goal-1',
      metric: .workouts,
      cadence: .week,
      stages: [GoalStage(id: 's0', target: 4)],
    );

    setUp(() {
      when(db.getWorkoutHistory('u1')).thenAnswer((_) async => [finished]);
      when(db.getActiveWorkout('u1')).thenAnswer((_) async => going);
      when(
        db.getTargetUserGoals(
          requesterId: anyNamed('requesterId'),
          targetUserId: anyNamed('targetUserId'),
          archived: anyNamed('archived'),
        ),
      ).thenAnswer((_) async => <Goal>[]);
      when(
        api.getTargetUserGoals(
          requesterId: anyNamed('requesterId'),
          targetUserId: anyNamed('targetUserId'),
          archived: anyNamed('archived'),
        ),
      ).thenAnswer((_) async => <Goal>[]);
      when(
        db.getTargetUserGoals(requesterId: 'u1', targetUserId: 'u1', archived: false),
      ).thenAnswer((_) async => [goal]);
      when(db.getChartRows('u1')).thenAnswer(
        (_) async => [
          ChartPreference.create(id: 'pref-1', type: .topSetWeight, data: {'exerciseName': 'bench-press'}).toRow(),
        ],
      );
    });

    /// The account signed in, with its workout in progress, its history and
    /// its goals read — startup's own reads, which a widget test never gets
    /// to, run by hand.
    Future<BuildContext> pumpSignedIn(WidgetTester tester, MockFirebaseAuth firebase) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await harness.pumpHeartApp(tester, db: db, api: api, cdn: cdn, firebaseAuth: firebase, settle: false);
      await tester.pumpTimes();
      final context = tester.element(find.byType(ProfilePage));
      unawaited(Workouts.of(context).init());
      unawaited(Workouts.of(context).initHistory());
      unawaited(Goals.of(context).init());
      await tester.pumpTimes();
      return context;
    }

    /// Firebase's own sign-out. The mock mints the next anonymous user from
    /// `mockUser`, which has to be an anonymous one by then; swapping it
    /// raises no event of its own.
    Future<void> signedOutByFirebase(WidgetTester tester, MockFirebaseAuth firebase) async {
      firebase.mockUser = MockUser(uid: 'anonymous', isAnonymous: true);
      await firebase.signOut();
      await tester.pumpTimes();
    }

    void expectNothingOfTheAccount(BuildContext context) {
      final auth = Auth.of(context);
      expect(auth.isAnonymous, isTrue);
      expect(auth.user?.id, 'anonymous');
      expect(find.byKey(AppKeys.noAccount), findsOneWidget);
      final workouts = Workouts.of(context);
      expect(workouts.activeWorkout, isNull, reason: "the account's workout in progress");
      expect(workouts.lookup(finished.id), isNull, reason: "the account's history");
      expect(Goals.of(context), isEmpty, reason: "the account's goals");
      expect(Charts.of(context), isEmpty, reason: "the account's dashboard");
    }

    testWidgets("shows nothing of the account's, which is its own again when it signs back in", (tester) async {
      final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
      final context = await pumpSignedIn(tester, firebase);
      final workouts = Workouts.of(context);
      expect(workouts.activeWorkout?.name, 'Legs');
      expect(workouts.lookup(finished.id), isNotNull);
      expect(Goals.of(context), isNotEmpty);
      expect(Charts.of(context), isNotEmpty);

      await signedOutByFirebase(tester, firebase);
      expectNothingOfTheAccount(context);

      // signed back in: the device kept what was the account's, and reads it
      // again under its uid
      firebase.mockUser = _passwordAccount();
      await firebase.signInWithCredential(null);
      await tester.pumpTimes();
      expect(Auth.of(context).user?.id, 'u1');
      expect(Charts.of(context), isNotEmpty);
    });

    testWidgets('what the account was still reading stays out of the next session', (tester) async {
      final history = Completer<Iterable<Workout>?>();
      when(db.getWorkoutHistory('u1')).thenAnswer((_) => history.future);
      final catalog = Completer<(DateTime?, Iterable<Exercise>)>();
      when(db.getExercises(userId: 'u1')).thenAnswer((_) => catalog.future);
      final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
      final context = await pumpSignedIn(tester, firebase);
      final exercises = Exercises.of(context);
      final initialized = exercises.init();
      await tester.pumpTimes();

      await signedOutByFirebase(tester, firebase);
      history.complete([finished]);
      catalog.complete((null, [Exercise(name: 'Squat', category: .barbell, target: .chest)]));
      await tester.pumpTimes();

      expect(Workouts.of(context).lookup(finished.id), isNull);
      expect(Workouts.of(context).historyInitialized, isFalse);
      // or the next session's startup would take its catalog for read
      expect(await initialized, isFalse);
      expect(exercises.isInitialized, isFalse);
      expect(exercises, isEmpty);
    });
  });

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
      expect(find.text('Confirm you want to delete your account'), findsOneWidget);
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

    group('conversations that stay with the other person (#568)', () {
      final holding = Thread(id: 't1', connectionId: 'c1', otherName: 'Whiskers', lastAt: DateTime.utc(2026, 11, 14));
      const coaching = {'feature-yourCoach': 'on'};

      setUp(() {
        when(db.storeThread(any, any)).thenAnswer((_) async {});
        when(db.storeThreads(any, any)).thenAnswer((_) async {});
        when(db.getThreadItems(any, any)).thenAnswer((_) async => []);
        when(db.deleteThreadItems(any, any)).thenAnswer((_) async {});
      });

      testWidgets('are said once the inbox arrives, and can be deleted first, for both', (tester) async {
        var cleared = false;
        when(db.getThreads(any)).thenAnswer((_) async => []);
        // the server drops the time of the last message with them
        when(api.getThreads()).thenAnswer(
          (_) async => [
            switch (cleared) {
              true => Thread(
                id: 't1',
                connectionId: 'c1',
                otherName: 'Whiskers',
                clearedAt: DateTime.utc(2026, 11, 15),
              ),
              false => holding,
            },
          ],
        );
        when(api.clearThread('t1')).thenAnswer((_) async => cleared = true);
        final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
        await pumpToAccountManagement(tester, firebase: firebase, prefs: coaching);

        await tester.tap(find.text('Delete account'));
        await tester.pumpTimes();
        expect(find.textContaining('Your conversation stays with the other person'), findsOneWidget);

        await tester.tapByKey(AppKeys.deleteAccountConversations);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.deleteAccountConversationsConfirm);
        await tester.pumpTimes();

        verify(api.clearThread('t1')).called(1);
        expect(find.text('Your messages are deleted for both sides.'), findsOneWidget);
        expect(find.byKey(AppKeys.deleteAccountConversations), findsNothing);
        verifyNever(api.deleteAccount(accountId: anyNamed('accountId'), appleGrant: anyNamed('appleGrant')));
      });

      testWidgets('one that could not be deleted is said in the dialog, and offered again', (tester) async {
        when(db.getThreads(any)).thenAnswer((_) async => []);
        when(api.getThreads()).thenAnswer((_) async => [holding]);
        when(api.clearThread('t1')).thenThrow(Exception('offline'));
        final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
        await pumpToAccountManagement(tester, firebase: firebase, prefs: coaching);

        await tester.tap(find.text('Delete account'));
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.deleteAccountConversations);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.deleteAccountConversationsConfirm);
        await tester.pumpTimes();

        expect(find.text("Couldn't delete a conversation. Try again."), findsOneWidget);
        expect(find.byKey(AppKeys.deleteAccountConversations), findsOneWidget);
      });

      testWidgets('while they are being deleted, the account cannot be, nor are they deleted twice', (tester) async {
        final server = Completer<void>();
        when(db.getThreads(any)).thenAnswer((_) async => []);
        when(api.getThreads()).thenAnswer((_) async => [holding]);
        when(api.clearThread('t1')).thenAnswer((_) => server.future);
        final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
        await pumpToAccountManagement(tester, firebase: firebase, prefs: coaching);

        await tester.tap(find.text('Delete account'));
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.deleteAccountConversations);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.deleteAccountConversationsConfirm);
        await tester.pump();

        expect(find.byKey(AppKeys.deleteAccountConversations), findsNothing);
        expect(find.text('Yep, go on without me!'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

        server.complete();
        await tester.pumpTimes();
        expect(find.text('Yep, go on without me!'), findsOneWidget);
        verify(api.clearThread('t1')).called(1);
      });

      testWidgets('a conversation that holds nothing is not mentioned', (tester) async {
        final emptied = Thread(
          id: 't1',
          connectionId: 'c1',
          otherName: 'Whiskers',
          clearedAt: DateTime.utc(2026, 11, 15),
        );
        when(db.getThreads(any)).thenAnswer((_) async => []);
        when(api.getThreads()).thenAnswer((_) async => [emptied]);
        final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
        await pumpToAccountManagement(tester, firebase: firebase, prefs: coaching);

        await tester.tap(find.text('Delete account'));
        await tester.pumpTimes();

        verify(api.getThreads()).called(greaterThanOrEqualTo(1));
        expect(find.textContaining('stays with the other person'), findsNothing);
        expect(find.byKey(AppKeys.deleteAccountConversations), findsNothing);
      });

      testWidgets('with coaching off, nothing is said of them, nor read', (tester) async {
        when(db.getThreads(any)).thenAnswer((_) async => [holding]);
        when(api.getThreads()).thenAnswer((_) async => [holding]);
        final firebase = MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true);
        await pumpToAccountManagement(tester, firebase: firebase);

        await tester.tap(find.text('Delete account'));
        await tester.pumpTimes();

        expect(find.textContaining('stays with the other person'), findsNothing);
        expect(find.byKey(AppKeys.deleteAccountConversations), findsNothing);
        verifyNever(api.getThreads());
      });
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

      expect(find.text('Confirm you want to delete your account'), findsNothing);
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

  group('sign-ins (#323)', () {
    testWidgets('a password account offers Google to connect, and keeps its only sign-in', (tester) async {
      await pumpToAccountManagement(tester, firebase: MockFirebaseAuth(mockUser: _passwordAccount(), signedIn: true));

      expect(find.text('Sign-ins'), findsOneWidget);
      expect(find.byKey(AppKeys.connectSignIn('google')), findsOneWidget);
      // the last sign-in has no Disconnect: absent, not dead
      expect(find.byKey(AppKeys.disconnectSignIn('password')), findsNothing);
      expect(find.byKey(AppKeys.connectSignIn('password')), findsNothing);
    });

    testWidgets('a Google account shows its address and offers to set a password', (tester) async {
      await pumpToAccountManagement(tester, firebase: MockFirebaseAuth(mockUser: _providerAccount(), signedIn: true));

      expect(find.byKey(AppKeys.connectSignIn('google')), findsNothing);
      expect(find.byKey(AppKeys.disconnectSignIn('google')), findsNothing);
      expect(find.text('Set a password'), findsOneWidget);

      // the password is set through the reset email: the same dialog
      await tester.tap(find.text('Set a password'));
      await tester.pumpTimes();
      expect(find.text('Reset password', skipOffstage: false), findsWidgets);
    });

    testWidgets('with two sign-ins either can be disconnected, and the row flips to Connect', (tester) async {
      await pumpToAccountManagement(
        tester,
        firebase: MockFirebaseAuth(mockUser: _twoProviderAccount(), signedIn: true),
      );

      expect(find.byKey(AppKeys.disconnectSignIn('google')), findsOneWidget);
      expect(find.byKey(AppKeys.disconnectSignIn('password')), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.disconnectSignIn('google')));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.connectSignIn('google')), findsOneWidget);
      // one left: nothing offers to disconnect it
      expect(find.byKey(AppKeys.disconnectSignIn('password')), findsNothing);
    });
  });
}
