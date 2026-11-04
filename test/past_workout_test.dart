// A workout logged after the fact (#530), opt-in as `Feature.pastWorkouts`,
// through the real app: off, neither the Workout tab nor History has a way
// in; on, either one asks when it was, then opens History's editor on a new
// workout whose Save puts it in History like a finish, stored and sent. A
// workout in progress is never touched, and leaving stores nothing.
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show WorkoutDetail, WorkoutDetailKeys;
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

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
  });

  const userId = 'u1';
  const phone = Size(390, 844);
  const tablet = Size(1194, 834);
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
    when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.finishWorkout(any, any)).thenAnswer((_) async {});
    when(db.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(api.saveWorkout(any)).thenAnswer((i) async => i.positionalArguments.single as Workout);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
  });

  /// The app at [size], signed in, with past workouts [on] or never asked.
  Future<BuildContext> launch(WidgetTester tester, {required bool on, Size size = phone}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (on) SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-pastWorkouts': 'on'});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: userId, email: '$userId@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    // the startup chain never resolves under a widget test's clock
    await Exercises.of(context).init();
    await tester.pumpTimes();
    return context;
  }

  Future<void> openTab(WidgetTester tester, Key tab) async {
    await tester.tapByKey(tab);
    await tester.pumpTimes();
  }

  /// To the minute, as the wheels pick it.
  DateTime minutes(DateTime at) => DateTime(at.year, at.month, at.day, at.hour, at.minute);

  /// Yesterday, 18:00 to 19:15, local.
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final start = DateTime(yesterday.year, yesterday.month, yesterday.day, 18);
  final end = start.add(const Duration(minutes: 75));

  /// Picks [start] and [end] on the open dialog's wheels.
  Future<void> pickTimes(WidgetTester tester) async {
    expect(find.text('When was it?'), findsOneWidget);
    await tester.tap(find.text('Start time'));
    await tester.pumpTimes();
    tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).onDateTimeChanged(start);
    await tester.pumpTimes();
    await tester.tap(find.text('End time'));
    await tester.pumpTimes();
    tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).onDateTimeChanged(end);
    await tester.pumpTimes();
    await tester.tap(find.text('Next'));
    await tester.pumpTimes();
    expect(find.text('When was it?'), findsNothing);
  }

  /// Bench, 100 × 5 twice, into the open editor.
  Future<void> fillIn(WidgetTester tester) async {
    await tester.tapByKey(WorkoutDetailKeys.addExercises);
    await tester.pumpTimes();
    await tester.tap(find.text('Bench Press').last);
    await tester.pumpTimes();
    await tester.tapByKey(WorkoutDetailKeys.addExerciseButton);
    await tester.pumpTimes();

    await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.weightFor(bench.id, 1)), '100');
    await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.repsFor(bench.id, 1)), '5');
    await tester.pumpTimes();
    await tester.ensureVisible(find.byKey(WorkoutDetailKeys.addSet));
    await tester.tapByKey(WorkoutDetailKeys.addSet);
    await tester.pumpTimes();
  }

  Finder save() => find.widgetWithText(PrimaryButton, 'Save');

  double saveOpacity(WidgetTester tester) {
    return tester.widget<AnimatedOpacity>(find.ancestor(of: save(), matching: find.byType(AnimatedOpacity))).opacity;
  }

  /// What Save put in the mirror and sent, checked against what was picked
  /// and filled in, and shown in History.
  Future<void> expectLogged(WidgetTester tester, BuildContext context) async {
    final stored = verify(db.finishWorkout(captureAny, userId)).captured.single as Workout;
    expect(stored.start, minutes(start).toUtc());
    expect(stored.end, minutes(end).toUtc());
    expect(stored.duration, const Duration(minutes: 75));
    expect(stored.map((each) => each.exercise.id), [bench.id]);
    expect(stored.single.length, 2, reason: 'the added set is a copy of the first');
    // 100 typed in the default unit, pounds, and kept in kilograms
    expect(stored.single.map((set) => (set.isCompleted, set.weight?.toStringAsFixed(2), set.reps)), [
      (true, '45.36', 5),
      (true, '45.36', 5),
    ]);
    // named on Save, as a finish names it, but for when it was: 18:00
    expect(stored.name, endsWith('Evening'));
    verify(api.saveWorkout(any)).called(1);

    final workouts = Workouts.of(context);
    expect(workouts.history.map((each) => each.id), [stored.id]);
    expect(workouts.hasActiveWorkout, isFalse, reason: 'nothing ran');
    expect(find.byType(WorkoutEditor), findsNothing, reason: 'Save leaves');
    expect(find.byType(WorkoutItem), findsOneWidget, reason: 'it is in History');
  }

  group('off', () {
    testWidgets('neither the Workout tab nor History has a way in', (tester) async {
      final context = await launch(tester, on: false);

      await openTab(tester, AppKeys.workoutStack);
      expect(find.byKey(WorkoutDetailKeys.startNewWorkout), findsOneWidget);
      expect(find.byKey(WorkoutDetailKeys.logPastWorkout), findsNothing);
      expect(find.byTooltip('Log a past workout'), findsNothing);

      await openTab(tester, AppKeys.historyStack);
      expect(find.byKey(AppKeys.logPastWorkout), findsNothing);
      expect(find.byTooltip('Log a past workout'), findsNothing);

      // the switch is live: on, both appear without a restart
      Preferences.of(context).setFeature(.pastWorkouts, on: true);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.logPastWorkout), findsOneWidget);
      await openTab(tester, AppKeys.workoutStack);
      expect(find.byKey(WorkoutDetailKeys.logPastWorkout), findsOneWidget);
    });
  });

  group('on', () {
    for (final size in [phone, tablet]) {
      testWidgets(
        'from the Workout tab: when, then what, then Save puts it in History at $size',
        (tester) async {
          final context = await launch(tester, on: true, size: size);
          await openTab(tester, AppKeys.workoutStack);
          expect(find.byTooltip('Log a past workout'), findsOneWidget);

          await tester.tapByKey(WorkoutDetailKeys.logPastWorkout);
          await tester.pumpTimes();
          await pickTimes(tester);

          expect(find.byType(WorkoutEditor), findsOneWidget);
          expect(find.text('Log Workout'), findsOneWidget);
          expect(find.byType(WorkoutDetail), findsOneWidget);
          await fillIn(tester);

          await tester.tap(save());
          await tester.pumpTimes();
          await expectLogged(tester, context);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(.iOS),
      );

      testWidgets(
        'from History, beside a workout in progress, which it leaves alone at $size',
        (tester) async {
          final context = await launch(tester, on: true, size: size);
          final workouts = Workouts.of(context);
          await workouts.startWorkout(
            source: .blank,
            template: Workout(name: 'Legs')..add(bench),
          );
          final live = workouts.activeWorkout!;
          final liveStart = live.start;

          // the one time the app opens a running workout's sheet by itself,
          // already spent: it runs on, out of the way
          workouts.notifyOfActiveWorkout();
          await tester.pumpTimes();
          await openTab(tester, AppKeys.historyStack);
          await tester.tapByKey(AppKeys.logPastWorkout);
          await tester.pumpTimes();
          await pickTimes(tester);
          expect(find.text('Log Workout'), findsOneWidget);
          await fillIn(tester);

          await tester.tap(save());
          await tester.pumpTimes();

          final stored = verify(db.finishWorkout(captureAny, userId)).captured.single as Workout;
          expect(stored.id, isNot(live.id));
          expect(stored.start, minutes(start).toUtc());
          expect(stored.end, minutes(end).toUtc());
          verify(api.saveWorkout(any)).called(1);
          expect(workouts.activeWorkout?.id, live.id);
          expect(workouts.activeWorkout?.start, liveStart);
          expect(workouts.activeWorkout?.end, isNull);
          expect(workouts.history.map((each) => each.id), [stored.id]);
          expect(find.byType(WorkoutEditor), findsNothing);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(.iOS),
      );
    }

    testWidgets('the times default to the last hour, and Next with them opens the editor', (tester) async {
      await launch(tester, on: true);
      await openTab(tester, AppKeys.historyStack);
      final before = minutes(DateTime.now());

      await tester.tapByKey(AppKeys.logPastWorkout);
      await tester.pumpTimes();
      expect(find.text('When was it?'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpTimes();

      final editor = tester.widget<WorkoutEditor>(find.byType(WorkoutEditor));
      final logged = editor.copy;
      final at = logged.end!.toLocal();
      expect(at.isBefore(before) || at.isAfter(DateTime.now()), isFalse, reason: 'ends now, to the minute');
      expect(logged.end!.difference(logged.start), const Duration(hours: 1));
      expect(logged, isEmpty);
    });

    testWidgets('dismissing the times opens nothing and stores nothing', (tester) async {
      await launch(tester, on: true);
      await openTab(tester, AppKeys.historyStack);

      await tester.tapByKey(AppKeys.logPastWorkout);
      await tester.pumpTimes();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpTimes();

      expect(find.text('When was it?'), findsNothing);
      expect(find.byType(WorkoutEditor), findsNothing);
      verifyNever(db.finishWorkout(any, any));
    });

    for (final size in [phone, tablet]) {
      testWidgets('leaving with something entered asks, and quitting stores nothing at $size', (tester) async {
        final context = await launch(tester, on: true, size: size);
        await openTab(tester, AppKeys.historyStack);
        await tester.tapByKey(AppKeys.logPastWorkout);
        await tester.pumpTimes();
        await tester.tap(find.text('Next'));
        await tester.pumpTimes();
        await fillIn(tester);

        // the pushed route's back, or the pane's close
        switch (size) {
          case phone:
            await tester.tap(find.byType(BackButton));
          default:
            await tester.tapByKey(AppKeys.closeDetail);
        }
        await tester.pumpTimes();
        expect(find.text('Quit editing?'), findsOneWidget);
        await tester.tap(find.text('Quit this page'));
        await tester.pumpTimes();

        expect(find.byType(WorkoutEditor), findsNothing);
        verifyNever(db.finishWorkout(any, any));
        verifyNever(api.saveWorkout(any));
        expect(Workouts.of(context).history, isEmpty);
      });
    }

    testWidgets('leaving with nothing entered just leaves', (tester) async {
      await launch(tester, on: true);
      await openTab(tester, AppKeys.historyStack);
      await tester.tapByKey(AppKeys.logPastWorkout);
      await tester.pumpTimes();
      await tester.tap(find.text('Next'));
      await tester.pumpTimes();

      expect(saveOpacity(tester), lessThan(1), reason: 'nothing to save yet');
      await tester.tap(save());
      await tester.pumpTimes();
      expect(find.byType(WorkoutEditor), findsOneWidget, reason: 'a buzz, not a save');
      verifyNever(db.finishWorkout(any, any));

      await tester.tap(find.byType(BackButton));
      await tester.pumpTimes();

      expect(find.text('Quit editing?'), findsNothing);
      expect(find.byType(WorkoutEditor), findsNothing);
      verifyNever(db.finishWorkout(any, any));
    });

    testWidgets('Save is live the moment a typed set holds something', (tester) async {
      await launch(tester, on: true);
      await openTab(tester, AppKeys.historyStack);
      await tester.tapByKey(AppKeys.logPastWorkout);
      await tester.pumpTimes();
      await tester.tap(find.text('Next'));
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.addExercises);
      await tester.pumpTimes();
      await tester.tap(find.text('Bench Press').last);
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.addExerciseButton);
      await tester.pumpTimes();
      expect(saveOpacity(tester), lessThan(1), reason: 'an empty set is no set');

      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.weightFor(bench.id, 1)), '100');
      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.repsFor(bench.id, 1)), '5');
      await tester.pumpTimes();
      expect(saveOpacity(tester), 1);
    });

    testWidgets(
      'a workout of no time is refused, and the times stay up',
      (tester) async {
        await launch(tester, on: true);
        await openTab(tester, AppKeys.historyStack);
        await tester.tapByKey(AppKeys.logPastWorkout);
        await tester.pumpTimes();

        await tester.tap(find.text('End time'));
        await tester.pumpTimes();
        final wheel = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
        wheel.onDateTimeChanged(wheel.minimumDate!);
        await tester.pumpTimes();
        await tester.tap(find.text('Next'));
        await tester.pumpTimes();

        expect(find.text('The end has to come after the start.'), findsOneWidget);
        expect(find.text('When was it?'), findsOneWidget);
        expect(find.byType(WorkoutEditor), findsNothing);
      },
      variant: TargetPlatformVariant.only(.iOS),
    );
  });
}
