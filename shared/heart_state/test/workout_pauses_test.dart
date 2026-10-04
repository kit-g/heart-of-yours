import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/analytics.dart';
import 'package:heart_state/src/workouts.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

/// Pausing the active workout (#134).
///
/// `start` and `end` stay wall-clock times and a pause is an interval: every
/// clock is `end (or now) − start − Σ pauses`. Times are placed with `at:` and
/// a workout started an hour ago, so the arithmetic is exact.
void main() {
  final local = MockWorkoutService();
  final remote = MockRemoteWorkoutService();
  late Workouts sut;
  late ReportedAnalytics reported;

  /// What the device was last told, as `(pauses, pausedAt)`.
  late (List<WorkoutPause>, DateTime?)? stored;

  /// What a cold start reads back as the open pause.
  DateTime? openOnDisk;

  final bench = ex('Bench Press');
  final now = DateTime.timestamp();
  final start = now.subtract(const Duration(hours: 1));

  DateTime minute(int minutes) => start.add(Duration(minutes: minutes));

  List<(DateTime, DateTime)> spans(Iterable<WorkoutPause> pauses) => [
    for (final pause in pauses) (pause.start, pause.end),
  ];

  Workouts state() {
    return Workouts(
      service: local,
      remoteService: remote,
      analytics: Analytics(service: reported),
      persistPauses: (id, pauses, pausedAt) async {
        stored = ([...pauses], pausedAt);
      },
      pausedAtOf: (_) async => openOnDisk,
    )..userId = 'u1';
  }

  Future<(WorkoutExercise, ExerciseSet)> begin() async {
    final workout = Workout(name: 'Push')
      ..start = start
      ..add(bench);
    await sut.startWorkout(source: .blank, template: workout);
    final exercise = sut.activeWorkout!.first;
    final set = exercise.first..setMeasurements(weight: 100, reps: 5);
    return (exercise, set);
  }

  setUp(() {
    when(local.startWorkout(any, any)).thenAnswer((_) async {});
    when(local.finishWorkout(any, any)).thenAnswer((_) async {});
    when(local.markSetAsComplete(any)).thenAnswer((_) async {});
    when(local.markSetAsIncomplete(any)).thenAnswer((_) async {});
    when(local.storeMeasurements(any)).thenAnswer((_) async {});
    when(local.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
    when(local.deleteWorkout(any)).thenAnswer((_) async {});
    when(remote.saveWorkout(any)).thenAnswer((inv) async => inv.positionalArguments.first as Workout);
    when(remote.deleteWorkout(any)).thenAnswer((_) async => true);

    stored = null;
    openOnDisk = null;
    reported = ReportedAnalytics();
    sut = state();
  });

  test('a pause stops the clock, and resuming keeps it among the workout\'s pauses', () async {
    await begin();
    expect(sut.isPaused, isFalse);

    await sut.pause(at: minute(30));
    expect(sut.isPaused, isTrue);
    expect(sut.pausedAt, minute(30));
    expect(sut.elapsed, const Duration(minutes: 30), reason: 'frozen where it stopped');
    expect(sut.clockStart, start, reason: 'nothing closed yet');
    expect(sut.activeWorkout!.pauses, isEmpty, reason: 'an open pause is not on the workout');
    expect(stored!.$1, isEmpty);
    expect(stored!.$2, minute(30), reason: 'a cold start comes back paused');

    await sut.resume(at: minute(40));
    expect(sut.isPaused, isFalse);
    expect(spans(sut.activeWorkout!.pauses), [(minute(30), minute(40))]);
    expect(sut.clockStart, minute(10));
    expect(sut.elapsed!.inMinutes, 50);
    expect(spans(stored!.$1), [(minute(30), minute(40))]);
    expect(stored!.$2, isNull);
  });

  test('pausing twice is one pause, and resuming a running workout does nothing', () async {
    await begin();
    await sut.resume(at: minute(5));
    expect(sut.activeWorkout!.pauses, isEmpty);

    await sut.pause(at: minute(10));
    await sut.pause(at: minute(20));
    expect(sut.pausedAt, minute(10));
  });

  test('a pause never starts inside the last one, nor before the workout', () async {
    await begin();
    await sut.pause(at: minute(10));
    await sut.resume(at: minute(20));

    // a watch out of reach, its clock behind
    await sut.pause(at: minute(15));
    expect(sut.pausedAt, minute(20));

    await sut.resume(at: minute(25));
    expect(spans(sut.activeWorkout!.pauses), [(minute(10), minute(20)), (minute(20), minute(25))]);
  });

  test('no more pauses than the server keeps', () async {
    await begin();
    sut.activeWorkout!.pauses.addAll(
      List.generate(
        Workout.maxPauses,
        (i) => WorkoutPause(
          start: minute(0),
          end: minute(0).add(Duration(seconds: i)),
        ),
      ),
    );

    expect(sut.canPause, isFalse, reason: 'the controls that pause are absent at the limit');
    await sut.pause(at: minute(30));
    expect(sut.isPaused, isFalse);
  });

  test('a pause that arrives late never starts before a set ticked since', () async {
    final (exercise, set) = await begin();
    await sut.markSetAsComplete(exercise, set, at: minute(44));

    // decided at 40 on a watch out of reach, delivered after the tick
    await sut.pause(at: minute(40));

    expect(sut.pausedAt, minute(44));
  });

  test('resuming a pause placed ahead of the clock runs it again, and keeps nothing', () async {
    await begin();
    // a skewed watch's clock, ahead of the phone's
    await sut.pause(at: now.add(const Duration(minutes: 2)));

    await sut.resume();

    expect(sut.isPaused, isFalse);
    expect(sut.activeWorkout!.pauses, isEmpty);
    expect(stored?.$1, isEmpty);
    expect(stored?.$2, isNull, reason: 'stored as running');
  });

  test('a set being timed stops with the workout, and stays stopped when it resumes', () async {
    final plank = Exercise(name: 'Plank', category: .duration, target: .core);
    await sut.startWorkout(
      source: .blank,
      template: Workout(name: 'Core')
        ..start = start
        ..add(plank),
    );
    await sut.stopwatch.start(sut.activeWorkout!, sut.activeWorkout!.first.first);

    await sut.pause(at: minute(30));
    expect(sut.stopwatch.isPaused, isTrue);

    await sut.resume(at: minute(35));
    expect(sut.stopwatch.isPaused, isTrue, reason: 'the user may not be back at that set');
  });

  test('ticking a set while paused resumes the workout then; typing into one does not', () async {
    final (exercise, set) = await begin();
    await sut.pause(at: minute(30));

    await sut.editSet(set, weight: 105);
    expect(sut.isPaused, isTrue);

    await sut.markSetAsComplete(exercise, set, at: minute(45));
    expect(sut.isPaused, isFalse);
    expect(spans(sut.activeWorkout!.pauses), [(minute(30), minute(45))]);
    expect(stored!.$2, isNull);
  });

  test('a tick is timed, and untimed again when it is taken back', () async {
    final (exercise, set) = await begin();

    await sut.markSetAsComplete(exercise, set, at: minute(42));
    expect(set.completedAt, minute(42));
    expect(sut.lastTickedAt, minute(42));

    await sut.markSetAsIncomplete(exercise, set);
    expect(set.completedAt, isNull);
    expect(sut.lastTickedAt, isNull);
  });

  test('finishing while paused closes the pause at the finish, and the duration leaves it out', () async {
    final (exercise, set) = await begin();
    await sut.markSetAsComplete(exercise, set, at: minute(5));
    await sut.pause(at: minute(40));

    final finished = await sut.finishActiveWorkout(at: minute(60));

    expect(sut.isPaused, isFalse);
    expect(spans(finished!.pauses), [(minute(40), minute(60))]);
    expect(finished.duration, const Duration(minutes: 40));
    // the time trained, not the time on the clock
    expect(reported.parametersOf('workout_finished')['duration_min'], 40);
  });

  test('a finish placed back in time cuts the pauses taken since', () async {
    final (exercise, set) = await begin();
    await sut.pause(at: minute(10));
    await sut.resume(at: minute(15));
    await sut.pause(at: minute(18));
    // the tick resumes the pause it lands in
    await sut.markSetAsComplete(exercise, set, at: minute(20));
    // forgotten, and paused long after the last set
    await sut.pause(at: minute(50));

    final finished = await sut.finishActiveWorkout(at: sut.lastTickedAt);

    expect(sut.isPaused, isFalse, reason: 'the open pause began after the end, and is no part of it');
    expect(finished!.end, minute(20));
    expect(spans(finished.pauses), [(minute(10), minute(15)), (minute(18), minute(20))]);
    expect(finished.duration, const Duration(minutes: 13));
  });

  test('the save carries the pauses to the server', () async {
    final (exercise, set) = await begin();
    await sut.markSetAsComplete(exercise, set, at: minute(5));
    await sut.pause(at: minute(10));
    await sut.resume(at: minute(20));
    await sut.finishActiveWorkout(at: minute(60));

    final sent = verify(remote.saveWorkout(captureAny)).captured.last as Workout;
    expect(sent.toMap()['pauses'], [
      {'start': minute(10).toIso8601String(), 'end': minute(20).toIso8601String()},
    ]);
  });

  test('a cold start comes back paused, with the pauses it had closed', () async {
    final workout = Workout(name: 'Push')
      ..start = start
      ..pauses = [WorkoutPause(start: minute(5), end: minute(10))];
    when(local.getActiveWorkout(any)).thenAnswer((_) async => workout);
    openOnDisk = minute(30);

    await sut.init();

    expect(sut.isPaused, isTrue);
    expect(sut.elapsed, const Duration(minutes: 25));
    expect(sut.clockStart, minute(5));
  });

  test('cancelling a paused workout leaves nothing paused for the next', () async {
    await begin();
    await sut.pause(at: minute(30));
    await sut.cancelActiveWorkout();
    expect(sut.isPaused, isFalse);

    await sut.startWorkout(source: .blank, name: 'Pull');
    expect(sut.isPaused, isFalse);
    expect(sut.activeWorkout!.pauses, isEmpty);
  });

  test('a copy from the server without detail brings its pauses', () async {
    final held = Workout.fromJson({
      'id': 'w1',
      'name': 'Push',
      'start': '2026-10-03T18:00:00.000Z',
      'end': '2026-10-03T19:00:00.000Z',
      'exercises': [
        {
          'id': 'we1',
          'exercise': {'id': 'bench', 'name': 'Bench', 'category': 'Barbell', 'target': 'Chest'},
          'sets': [
            {'id': 's1', 'completed': true, 'reps': 5, 'weight': 100},
          ],
        },
      ],
    });
    final shallow = Workout.fromJson({
      'id': 'w1',
      'name': 'Push',
      'start': '2026-10-03T18:00:00.000Z',
      'end': '2026-10-03T19:00:00.000Z',
      'pauses': [
        {'start': '2026-10-03T18:10:00.000Z', 'end': '2026-10-03T18:20:00.000Z'},
      ],
    });
    when(local.getWorkout(any, any)).thenAnswer((_) async => held);
    await sut.fetchWorkout('w1');
    when(remote.patchWorkout(any, start: anyNamed('start'), end: anyNamed('end'))).thenAnswer((_) async => shallow);

    await sut.editWorkoutTimes('w1', end: DateTime.utc(2026, 10, 3, 19));

    final kept = sut.lookup('w1')!;
    expect(kept.single.single.id, 's1');
    expect(kept.duration, const Duration(minutes: 50));
  });
}
