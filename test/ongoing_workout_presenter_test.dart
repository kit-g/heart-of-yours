import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/presentation/navigation/ongoing_workout.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The active workout on the lock screen (#133): what reaches the platform,
/// and — as much the point — what does not. Workouts notifies on every
/// keystroke in a set row; the surface must hear only real changes.
void main() {
  late MockWorkoutService local;
  late Workouts workouts;
  late Alarms alarms;
  late AppTheme theme;
  late Preferences preferences;
  late Exercises exercises;
  late _Surface surface;

  final bench = Exercise.fromJson({
    'id': 'id-bench',
    'name': 'Bench Press (Barbell)',
    'category': 'Barbell',
    'target': 'Chest',
    'archived': false,
  });

  Workout push() {
    final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5))
      ..add(ExerciseSet(bench, weight: 62.5, reps: 5))
      ..add(ExerciseSet(bench));
    return Workout.fromExercises([block], name: 'Push day');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    // opt-in (#133); the tests below that are about it switch it back off
    preferences.lockScreenWorkout = true;

    local = MockWorkoutService();
    workouts = Workouts(service: local, remoteService: MockRemoteWorkoutService())..userId = 'u1';
    alarms = Alarms();
    theme = AppTheme()..preset = .forge;
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    surface = _Surface();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Alarms>.value(value: alarms),
          ChangeNotifierProvider<AppTheme>.value(value: theme),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => OngoingWorkoutPresenter(surface: surface, child: child!),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('nothing is torn down before the active workout is known', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => null);

    await pump(tester);
    expect(surface.calls, isEmpty, reason: 'not loaded yet is not "none" — a live activity may be re-attached');

    await workouts.init();
    await tester.pump();
    expect(surface.calls, ['end'], reason: 'a workout left on the lock screen by a killed process goes');

    // any notify: pointing at an exercise is a public one that changes nothing here
    workouts.pointedAtExercise = null;
    await tester.pump();
    expect(surface.calls, ['end'], reason: 'once is enough');
  });

  testWidgets('a resumed workout is shown with its next set, in the preferred unit', (tester) async {
    final workout = push();
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);

    await pump(tester);
    await workouts.init();
    await tester.pump();

    final shown = surface.last!;
    expect(shown.workoutId, workout.id);
    expect(shown.startedAt, workout.start);
    expect(shown.title, 'Push day');
    expect(shown.exercise, 'Bench Press (Barbell)');
    expect(shown.next, 'Next: set 1 · 60 kg x 5');
    expect(shown.rest, isNull);
    expect(shown.preset, Preset.forge);
    expect(shown.channel, 'Workout in progress');
  });

  testWidgets('a notify that changes nothing does not reach the platform', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());

    await pump(tester);
    await workouts.init();
    await tester.pump();
    final before = surface.calls.length;

    // what typing into a set row's field looks like from here: a notify that
    // leaves the summary as it was
    workouts.pointedAtExercise = null;
    workouts.pointedAtExercise = null;
    await tester.pump();

    expect(surface.calls.length, before);
  });

  testWidgets('ticking a set moves "next" along, and an empty set says only its number', (tester) async {
    final workout = push();
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);

    await pump(tester);
    await workouts.init();
    await tester.pump();

    final block = workout.first;
    await workouts.markSetAsComplete(block, block.elementAt(0));
    await tester.pump();
    expect(surface.last!.next, 'Next: set 2 · 62.5 kg x 5');

    await workouts.markSetAsComplete(block, block.elementAt(1));
    await tester.pump();
    expect(surface.last!.next, 'Next: set 3');

    await workouts.markSetAsComplete(block, block.elementAt(2));
    await tester.pump();
    expect(surface.last!.next, 'All sets done');
  });

  testWidgets('a rest is sent as its window, and taken away when it stops', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());

    await pump(tester);
    await workouts.init();
    await tester.pump();

    alarms.startActiveExerciseTimer(90, exerciseId: 'id-bench');
    await tester.pump();

    final rest = surface.last!.rest!;
    expect(rest.end.difference(rest.start), const Duration(seconds: 90));
    expect(rest.label, 'Rest');
    expect(rest.over, 'Rest complete!');

    alarms.adjustActiveExerciseTime(30);
    await tester.pump();
    final adjusted = surface.last!.rest!;
    expect(adjusted.end.difference(rest.end), const Duration(seconds: 30));
    expect(adjusted.start, rest.start, reason: 'an adjustment moves the end, not when the rest began');

    alarms.stopActiveExerciseTimer();
    await tester.pump();
    expect(surface.last!.rest, isNull);
  });

  testWidgets('finishing or cancelling the workout takes it off the lock screen', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());

    await pump(tester);
    await workouts.init();
    await tester.pump();

    await workouts.cancelActiveWorkout();
    await tester.pump();

    expect(surface.calls.last, 'end');
  });

  group('the setting', () {
    testWidgets('is off on a fresh install, and nothing is shown', (tester) async {
      SharedPreferences.setMockInitialValues({});
      preferences = Preferences();
      await preferences.init();
      expect(preferences.lockScreenWorkout, isFalse);

      when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());
      await pump(tester);
      await workouts.init();
      await tester.pump();

      expect(surface.calls, ['end'], reason: 'off means no workout — and one left up by a previous run goes');
    });

    testWidgets('turned off mid-workout takes it down, turned on puts it back', (tester) async {
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());
      await pump(tester);
      await workouts.init();
      await tester.pump();
      expect(surface.calls, ['show']);

      preferences.lockScreenWorkout = false;
      await tester.pump();
      expect(surface.calls, ['show', 'end']);

      preferences.lockScreenWorkout = true;
      await tester.pump();
      expect(surface.calls, ['show', 'end', 'show']);
    });
  });

  testWidgets('without a surface nothing is attempted', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Alarms>.value(value: alarms),
          ChangeNotifierProvider<AppTheme>.value(value: theme),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => OngoingWorkoutPresenter(surface: null, child: child!),
          home: const Text('home'),
        ),
      ),
    );
    await workouts.init();
    await tester.pump();

    expect(find.text('home'), findsOneWidget);
    expect(surface.calls, isEmpty);
  });
}

class _Surface implements OngoingWorkoutSurface {
  final calls = <String>[];
  OngoingWorkout? last;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> show(OngoingWorkout workout) async {
    calls.add('show');
    last = workout;
  }

  @override
  Future<void> end() async => calls.add('end');
}
