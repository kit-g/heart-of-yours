import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
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

/// The active workout's start and end, set by hand (#530), opt-in as
/// `Feature.workoutTimes`: the clock opens the start's picker, and the finish
/// of a workout whose start moved offers its end. Off, the clock is a clock.
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

  /// To the minute, as the wheel picks it.
  DateTime minutes(DateTime at) => DateTime(at.year, at.month, at.day, at.hour, at.minute);

  /// The active workout's sheet, open, with workout times [on] or never asked.
  Future<Workouts> open(WidgetTester tester, {required bool on, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    if (on) SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-workoutTimes': 'on'});
    final ex = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [ex]));
    when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});
    when(db.finishWorkout(any, any)).thenAnswer((_) async {});
    when(db.setWorkoutStart(any, any, any, any)).thenAnswer((_) async {});
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
    final exercise = workouts.activeWorkout!.first;
    exercise.first.setMeasurements(weight: 100, reps: 5);
    await workouts.markSetAsComplete(exercise, exercise.first);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    return workouts;
  }

  String clock(WidgetTester tester) {
    final text = find.descendant(of: find.byKey(WorkoutDetailKeys.timer), matching: find.byType(Text));
    return tester.widget<Text>(text).data!;
  }

  /// Turns the open wheel to [at].
  void turn(WidgetTester tester, DateTime at) {
    tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).onDateTimeChanged(at);
  }

  testWidgets('off, the clock is only a clock', (tester) async {
    await open(tester, on: false);

    expect(find.byKey(WorkoutDetailKeys.timer), findsOneWidget);
    expect(find.byKey(WorkoutDetailKeys.startTime), findsNothing);
    expect(find.byTooltip('Change when this workout started'), findsNothing);
    final style = tester.widget<Text>(
      find.descendant(of: find.byKey(WorkoutDetailKeys.timer), matching: find.byType(Text)),
    );
    expect(style.style?.decoration, isNot(TextDecoration.underline), reason: 'no affordance either');

    await tester.tap(find.byKey(WorkoutDetailKeys.timer));
    await tester.pumpTimes();
    expect(find.text('Adjust Start/End Time'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('off, a finish offers no end, whatever happened to the start', (tester) async {
    final workouts = await open(tester, on: false);
    await workouts.moveStart(DateTime.timestamp().subtract(const Duration(hours: 2)));
    await tester.pumpTimes();

    await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
    await tester.pumpTimes();
    expect(find.text("Yes, I'm done!"), findsOneWidget, reason: 'the finish dialog is up');
    expect(find.byKey(WorkoutDetailKeys.endTime), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(390, 844), const Size(1194, 834)]) {
    testWidgets(
      'on, the clock opens the start, and the start it is given shows and is stored at $size',
      (tester) async {
        final workouts = await open(tester, on: true, size: size);
        expect(find.byTooltip('Change when this workout started'), findsOneWidget);

        await tester.tapByKey(WorkoutDetailKeys.startTime);
        await tester.pumpTimes();
        expect(find.text('Adjust Start/End Time'), findsOneWidget);
        expect(find.text('End time'), findsNothing, reason: 'a running workout has no end yet');

        await tester.tap(find.text('Start time'));
        await tester.pumpTimes();
        final earlier = minutes(DateTime.now()).subtract(const Duration(minutes: 90));
        turn(tester, earlier);
        await tester.pumpTimes();
        await tester.tap(find.text('Save'));
        await tester.pumpTimes();

        expect(find.text('Adjust Start/End Time'), findsNothing);
        expect(workouts.activeWorkout!.start, earlier.toUtc());
        expect(workouts.startMoved, isTrue);
        expect(clock(tester), startsWith('01:30:'), reason: 'the clock counts from the new start');
        verify(db.setWorkoutStart(workouts.activeWorkout!.id, earlier.toUtc(), [], null)).called(1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(.iOS),
    );
  }

  testWidgets(
    'a finish after the start moved offers the end, and ends there',
    (tester) async {
      final workouts = await open(tester, on: true);
      final earlier = minutes(DateTime.now()).subtract(const Duration(hours: 3));
      await workouts.moveStart(earlier);
      await tester.pumpTimes();

      await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
      await tester.pumpTimes();
      expect(find.byKey(WorkoutDetailKeys.endTime), findsOneWidget);
      expect(find.byTooltip('Change when this workout ended'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget, reason: 'left alone, it ends now');

      await tester.tapByKey(WorkoutDetailKeys.endTime);
      await tester.pumpTimes();
      expect(find.text('Adjust Start/End Time'), findsOneWidget);
      await tester.tap(find.text('End time').last);
      await tester.pumpTimes();
      final end = earlier.add(const Duration(minutes: 75));
      turn(tester, end);
      await tester.pumpTimes();
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();

      expect(find.text('Adjust Start/End Time'), findsNothing);
      expect(find.text('Now'), findsNothing, reason: 'the row shows the end picked');

      await tester.tap(find.text("Yes, I'm done!"));
      await tester.pumpTimes();

      final finished = verify(db.finishWorkout(captureAny, any)).captured.single as Workout;
      expect(finished.start, earlier.toUtc());
      expect(finished.end, end.toUtc());
      expect(finished.duration, const Duration(minutes: 75));
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(.iOS),
  );

  testWidgets('on, a finish whose start never moved ends now and says nothing of it', (tester) async {
    final workouts = await open(tester, on: true);

    await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
    await tester.pumpTimes();
    expect(find.text("Yes, I'm done!"), findsOneWidget);
    expect(find.byKey(WorkoutDetailKeys.endTime), findsNothing);
    expect(workouts.startMoved, isFalse);
    await tester.pumpWidget(const SizedBox());
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
