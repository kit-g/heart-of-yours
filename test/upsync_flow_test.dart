// Link account and upsync the local store (#96), through the real app: an
// anonymous session logs into an existing account from its profile, the
// store moves onto the new uid, the replay runs with the remote leg held,
// the profile row reports it, and a failure is retryable from the same row.
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  /// The debt as the database would keep it.
  late bool owed;

  /// The one row the anonymous session holds: a finished workout the server
  /// has never seen.
  late Workout monday;

  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  Workout unsynced(String name) {
    final workout = Workout(name: name);
    workout.add(bench).add(ExerciseSet(bench, weight: 60, reps: 5)..isCompleted = true);
    workout.finish(DateTime.timestamp());
    return workout;
  }

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);

    owed = false;
    when(db.rekeyUser(any, any)).thenAnswer((_) async {});
    when(db.oweUpsync(any)).thenAnswer((_) async => owed = true);
    when(db.isUpsyncOwed(any)).thenAnswer((_) async => owed);
    when(db.settleUpsync(any)).thenAnswer((_) async => owed = false);
    when(db.recordUpsync(any, any)).thenAnswer((_) async {});
    // the same row on every read until the store is written to; a confirmed
    // copy stored marks it synced, as the real store does
    monday = unsynced('Monday');
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [monday]);
    when(db.storeWorkoutHistory(any, any)).thenAnswer((_) async {
      final synced = Workout.fromJson(monday.toMap()..remove('synced'));
      when(db.getWorkoutHistory(any)).thenAnswer((_) async => [synced]);
    });
    when(api.replayWorkout(any)).thenAnswer(
      (invocation) async => (row: invocation.positionalArguments.single as Workout, created: true),
    );
    // what the re-pull after a finished replay reaches for: the library, so
    // the catalog counts as loaded and the history pull follows
    when(cdn.getExerciseLibrary(cached: anyNamed('cached'))).thenAnswer(
      (_) async => (<Exercise>[bench], (version: '1', locale: 'en', etag: null)),
    );
  });

  L l(WidgetTester tester) => L.of(tester.element(find.byType(ProfilePage)));

  /// What start-up does once the API has its token: run the replay the sign-in
  /// owed. Start-up itself (`_initApp`) runs in `Zone.root`, which a widget
  /// test's fake-async zone never yields to, so the run is started here the
  /// way `_initApp` would — after the sign-in has settled and the gate is held.
  Future<Upsync> startReplay(WidgetTester tester) async {
    final context = tester.element(find.byType(ProfilePage));
    final upsync = Upsync.of(context);
    expect(RemoteAccess.of(context).allowed, isFalse, reason: 'held since the sign-in began');
    expect(await db.isUpsyncOwed(Auth.of(context).user!.id), isTrue);
    unawaited(upsync.run(Auth.of(context).user!.id));
    await tester.pumpTimes();
    return upsync;
  }

  /// An anonymous session on its profile, with what it holds under its uid.
  Future<(String uid, BuildContext context)> pumpAnonymous(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      settle: false,
    );
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);
    final context = tester.element(find.byType(ProfilePage));
    final auth = Auth.of(context);
    expect(auth.isAnonymous, isTrue);
    return (auth.user!.id, context);
  }

  /// Through the no-account dialog to the login page, and in with email —
  /// logging in is signing into an account that exists, so the uid changes.
  Future<void> logIn(WidgetTester tester) async {
    await tester.tapByKey(AppKeys.noAccount);
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.noAccountLogIn);
    await tester.pumpTimes();
    expect(find.byType(LoginPage), findsOneWidget);

    final strings = L.of(tester.element(find.byType(LoginPage)));
    await tester.enterTextAndWait(find.byType(TextFormField).at(0), 'acct@test.dev');
    await tester.enterTextAndWait(find.byType(TextFormField).at(1), 'Str0ng!Passw0rd');
    await tester.tap(find.widgetWithText(OutlinedButton, strings.logIn));
    await tester.pumpTimes();
  }

  testWidgets('existing account: the store moves onto the new uid, is replayed, and the row says so', (tester) async {
    final (anonymous, context) = await pumpAnonymous(tester);
    final preferences = Preferences.of(context);
    await preferences.setBaseColor(anonymous, 'ember');
    final remote = RemoteAccess.of(context);

    await logIn(tester);

    expect(find.byType(ProfilePage), findsOneWidget);
    final auth = Auth.of(tester.element(find.byType(ProfilePage)));
    final account = auth.user!.id;
    expect(auth.isAnonymous, isFalse);
    expect(account, isNot(anonymous));

    // the rows and the preferences moved, once, before anything else
    verify(db.rekeyUser(anonymous, account)).called(1);
    verify(db.oweUpsync(account)).called(1);
    expect(preferences.getBaseColor(account), 'ember');
    expect(preferences.getBaseColor(anonymous), isNull);
    verifyNever(api.replayWorkout(any));

    await startReplay(tester);

    // the one pending workout went up exactly once, and the debt was settled
    final replayed = verify(api.replayWorkout(captureAny)).captured.single as Workout;
    expect(replayed.id, monday.id);
    verify(db.storeWorkoutHistory(argThat(contains(monday)), account)).called(1);
    verifyNever(api.saveWorkout(any));
    verify(db.settleUpsync(account)).called(1);
    expect(remote.allowed, isTrue, reason: 'the leg opens once the replay is done');

    // one line, on the profile, with the numbers — and a way to put it away
    expect(find.byKey(AppKeys.upsyncRow), findsOneWidget);
    expect(find.text(l(tester).upsyncDone(1, 0)), findsOneWidget);
    await tester.tapByKey(AppKeys.upsyncDismiss);
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.upsyncRow), findsNothing);
  });

  testWidgets('while the server cannot be reached the row offers a retry, and the leg stays closed', (tester) async {
    when(api.replayWorkout(any)).thenAnswer((_) => Future.error(const SocketException('offline')));
    final (_, context) = await pumpAnonymous(tester);
    final remote = RemoteAccess.of(context);

    await logIn(tester);
    await startReplay(tester);

    final strings = l(tester);
    expect(find.text(strings.upsyncFailed(0, 1)), findsOneWidget);
    expect(find.byKey(AppKeys.upsyncRetry), findsOneWidget);
    expect(remote.allowed, isFalse, reason: 'the sweeps must not run ahead of the replay');
    verifyNever(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since')));

    // the network is back
    when(api.replayWorkout(any)).thenAnswer(
      (invocation) async => (row: invocation.positionalArguments.single as Workout, created: true),
    );
    await tester.tapByKey(AppKeys.upsyncRetry);
    await tester.pumpTimes();

    expect(find.text(strings.upsyncDone(1, 0)), findsOneWidget);
    expect(remote.allowed, isTrue);
    // the same row, sent twice in total: once refused by the network, once landed
    verify(api.replayWorkout(any)).called(2);
    // and only now does the app pull what the account holds
    verify(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since'))).called(1);
  });

  testWidgets('while it runs the row is a line and a bar', (tester) async {
    when(api.replayWorkout(any)).thenAnswer((_) => Completer<({Workout row, bool created})>().future);
    await pumpAnonymous(tester);

    await logIn(tester);
    await startReplay(tester);

    expect(find.text(l(tester).upsyncRunning(0, 1)), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(AppKeys.upsyncRetry), findsNothing);
    expect(find.byKey(AppKeys.upsyncDismiss), findsNothing);
  });

  testWidgets('a session with nothing owed shows no row', (tester) async {
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byKey(AppKeys.upsyncRow), findsNothing);
    verifyNever(api.replayWorkout(any));
  });
}
