import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Pausing the active workout (#134), opt-in as `Feature.pauseWorkout`: the
/// ⋯ menu's Pause, Resume beside the stopped clock, the switch both ways, and
/// the idle reminder's offer to finish at the last set.
void main() {
  // the app's own fonts, as the screens are laid out for them: the test font
  // is wider and overflows the app bars at phone width
  setUpAll(() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    // a finish withdraws the workout's notifications; no plugin registrant
    // runs under `flutter test` — see notification_refusal_test
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => null,
    );
  });

  late MockLocalDatabase db;

  /// The active workout's sheet, open, with pausing [on] or never asked.
  Future<Workouts> open(
    WidgetTester tester, {
    required bool on,
    Size size = const Size(390, 844),
    Future<void> Function(Workouts workouts)? beforeSheet,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    if (on) SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-pauseWorkout': 'on'});
    final ex = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [ex]));
    when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});
    when(db.finishWorkout(any, any)).thenAnswer((_) async {});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(mockUser: _AnonymousUser(), signedIn: true),
      settle: false,
    );
    final workouts = Workouts.of(tester.element(find.byType(MaterialApp)));
    await workouts.startWorkout(
      source: .template,
      template: Workout(name: 'Push day')
        ..add(ex)
        ..start = DateTime.timestamp().subtract(const Duration(minutes: 30)),
    );
    await beforeSheet?.call(workouts);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    return workouts;
  }

  String clock(WidgetTester tester) {
    final text = find.descendant(of: find.byKey(WorkoutDetailKeys.timer), matching: find.byType(Text));
    return tester.widget<Text>(text).data!;
  }

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tapByKey(WorkoutDetailKeys.options);
    await tester.pumpTimes();
    await tester.tap(find.text(item));
    await tester.pumpTimes();
  }

  testWidgets('off, the menu has no pause and the workout no resume', (tester) async {
    final workouts = await open(tester, on: false);

    await tester.tapByKey(WorkoutDetailKeys.options);
    await tester.pumpTimes();
    expect(find.text('Pause workout'), findsNothing);
    expect(find.text('Add note'), findsOneWidget, reason: 'the menu is open');
    await tester.tapAt(Offset.zero);
    await tester.pumpTimes();

    expect(find.byKey(WorkoutDetailKeys.resume), findsNothing);
    expect(workouts.isPaused, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(390, 844), const Size(1194, 834), const Size(834, 1194)]) {
    testWidgets('on, the menu pauses, the clock stops, the rest is skipped, and Resume starts it at $size', (
      tester,
    ) async {
      final workouts = await open(tester, on: true, size: size);
      final context = tester.element(find.byType(MaterialApp));
      final alarms = Alarms.of(context);
      alarms.startActiveExerciseTimer(90, exerciseId: workouts.activeWorkout!.first.id);
      await tester.pumpTimes();

      await menu(tester, 'Pause workout');

      expect(workouts.isPaused, isTrue);
      expect(alarms.activeExerciseId, isNull, reason: 'a pause skips the rest');
      verify(db.setWorkoutPauses(workouts.activeWorkout!.id, [], workouts.pausedAt)).called(1);
      expect(find.byKey(WorkoutDetailKeys.resume), findsOneWidget);
      expect(find.byTooltip('Resume workout'), findsOneWidget);
      final stopped = clock(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(clock(tester), stopped, reason: 'the clock stands still');

      await tester.tapByKey(WorkoutDetailKeys.options);
      await tester.pumpTimes();
      expect(find.text('Resume workout'), findsOneWidget, reason: 'the menu says what it would do now');
      await tester.tapAt(Offset.zero);
      await tester.pumpTimes();

      await tester.tapByKey(WorkoutDetailKeys.resume);
      await tester.pumpTimes();
      expect(workouts.isPaused, isFalse);
      expect(workouts.activeWorkout!.pauses, hasLength(1));
      expect(find.byKey(WorkoutDetailKeys.resume), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('switched off while paused, the clock runs again and the pause is kept', (tester) async {
    final workouts = await open(tester, on: true);
    await menu(tester, 'Pause workout');
    expect(workouts.isPaused, isTrue);
    await tester.pump(const Duration(seconds: 2));

    Preferences.of(tester.element(find.byType(MaterialApp))).setFeature(.pauseWorkout, on: false);
    await tester.pumpTimes();

    expect(workouts.isPaused, isFalse);
    expect(workouts.activeWorkout!.pauses, hasLength(1), reason: 'off never deletes');
    expect(find.byKey(WorkoutDetailKeys.resume), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  group('the idle reminder', () {
    final lastSet = DateTime.timestamp().subtract(const Duration(minutes: 10));

    Future<void> tickAndOffer(WidgetTester tester, Workouts workouts, {bool tick = true}) async {
      final exercise = workouts.activeWorkout!.first;
      if (tick) await workouts.markSetAsComplete(exercise, exercise.first, at: lastSet);
      // a pause taken after the last set, which the finish has to cut
      await workouts.pause(at: lastSet.add(const Duration(minutes: 2)));
      await tester.pumpTimes();
      final offered = offerFinishAtLastSet(tester.element(find.byType(WorkoutDetail)), workouts);
      await tester.pumpTimes();
      // nothing to answer when nothing was offered
      if (find.byKey(WorkoutDetailKeys.keepGoing).evaluate().isEmpty) await offered;
    }

    testWidgets('offers to finish at the last set, and does', (tester) async {
      final workouts = await open(tester, on: true);
      await tickAndOffer(tester, workouts);

      expect(find.textContaining('Finished at'), findsOneWidget);
      await tester.tapByKey(WorkoutDetailKeys.finishAtLastSet);
      await tester.pumpTimes();

      final finished = verify(db.finishWorkout(captureAny, any)).captured.single as Workout;
      expect(finished.end, lastSet);
      expect(finished.pauses, isEmpty, reason: 'the pause after the last set is cut');
      expect(workouts.isPaused, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('keep going leaves the workout as it was', (tester) async {
      final workouts = await open(tester, on: true);
      await tickAndOffer(tester, workouts);

      await tester.tapByKey(WorkoutDetailKeys.keepGoing);
      await tester.pumpTimes();

      verifyNever(db.finishWorkout(any, any));
      expect(workouts.hasActiveWorkout, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('offers nothing with no set ticked', (tester) async {
      final workouts = await open(tester, on: true);
      await tickAndOffer(tester, workouts, tick: false);

      expect(find.textContaining('Finished at'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('asked for from the reminder, the open sheet raises the offer', (tester) async {
      final workouts = await open(tester, on: true);
      final exercise = workouts.activeWorkout!.first;
      await workouts.markSetAsComplete(exercise, exercise.first, at: lastSet);

      requestFinishAtLastSet();
      await tester.pumpTimes();

      expect(find.textContaining('Finished at'), findsOneWidget);
      await tester.tapByKey(WorkoutDetailKeys.keepGoing);
      await tester.pumpTimes();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('asked for before the sheet is up, the sheet raises it once it is', (tester) async {
      await open(
        tester,
        on: true,
        beforeSheet: (workouts) async {
          final exercise = workouts.activeWorkout!.first;
          await workouts.markSetAsComplete(exercise, exercise.first, at: lastSet);
          // a notification tap on a cold start: the sheet is not up yet
          requestFinishAtLastSet();
        },
      );

      expect(find.textContaining('Finished at'), findsOneWidget);
      await tester.tapByKey(WorkoutDetailKeys.keepGoing);
      await tester.pumpTimes();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('offers nothing with pausing off', (tester) async {
      final workouts = await open(tester, on: false);
      final exercise = workouts.activeWorkout!.first;
      await workouts.markSetAsComplete(exercise, exercise.first, at: lastSet);
      await offerFinishAtLastSet(tester.element(find.byType(WorkoutDetail)), workouts);
      await tester.pumpTimes();

      expect(find.textContaining('Finished at'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

// MockUser otherwise supplies a remote avatar, unrelated to this offline flow.
// The upstream mock is mutable despite Firebase User's immutable annotation.
// ignore: must_be_immutable
class _AnonymousUser extends MockUser {
  new() : super(uid: 'anon', isAnonymous: true);

  @override
  String? get photoURL => null;
}
