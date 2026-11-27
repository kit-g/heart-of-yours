import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/remote.dart';
import 'package:heart_state/src/analytics.dart';
import 'package:heart_state/src/workouts.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

/// A workout logged after the fact (#530): it never runs, and it lands in
/// history the way a finish does, beside whatever workout is in progress.
void main() {
  final local = MockWorkoutService();
  final remote = MockRemoteWorkoutService();
  late Workouts sut;
  late RemoteAccess access;

  final bench = ex('Bench Press');
  final squat = ex('Squat');
  final end = DateTime.timestamp().subtract(const Duration(days: 2));
  final start = end.subtract(const Duration(minutes: 70));

  /// Yesterday's push day: bench with one set done and one ticked but empty,
  /// squat with nothing in it at all.
  Workout past() {
    final workout = Workout(name: 'Push')
      ..start = start
      ..end = end;
    workout.add(bench).first
      ..setMeasurements(reps: 8)
      ..isCompleted = true;
    final bare = ExerciseSet(bench)..isCompleted = true;
    workout.first.add(bare);
    workout.add(squat).first.isCompleted = true;
    return workout;
  }

  late ReportedAnalytics reported;

  setUp(() {
    reset(local);
    reset(remote);
    when(local.startWorkout(any, any)).thenAnswer((_) async {});
    when(local.finishWorkout(any, any)).thenAnswer((_) async {});
    when(local.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
    when(remote.saveWorkout(any)).thenAnswer((inv) async => inv.positionalArguments.first as Workout);

    access = RemoteAccess();
    reported = ReportedAnalytics();
    sut = Workouts(
      service: local,
      remoteService: remote,
      remote: access,
      analytics: Analytics(service: reported),
    )..userId = 'u1';
  });

  test('a past workout lands in history with its own times, stored and sent', () async {
    var heard = 0;
    sut.addListener(() => heard++);
    final revision = sut.historyRevision;

    final saved = await sut.logWorkout(past());

    expect(saved.start, start);
    expect(saved.end, end);
    expect(sut.history.map((each) => each.id), [saved.id]);
    expect(sut.historyRevision, greaterThan(revision), reason: 'stats, records and goals reread on this');
    expect(heard, greaterThan(0));

    final stored = verify(local.finishWorkout(captureAny, 'u1')).captured.single as Workout;
    expect(stored.id, saved.id);
    verify(remote.saveWorkout(any)).called(1);
    verify(local.storeWorkoutHistory(any, 'u1')).called(1);
  });

  test('only sets with something in them are kept', () async {
    final saved = await sut.logWorkout(past());

    expect(saved.map((exercise) => exercise.exercise.id), [bench.id], reason: 'an exercise of empty sets goes');
    expect(saved.single.length, 1);
    expect(saved.single.single.reps, 8);
    expect(saved.single.single.isCompleted, isTrue);
  });

  test('a workout in progress is left as it was', () async {
    final live = Workout(name: 'Legs')..add(squat);
    await sut.startWorkout(source: .blank, template: live);
    final liveStart = sut.activeWorkout!.start;

    final saved = await sut.logWorkout(past());

    expect(sut.activeWorkout?.id, live.id);
    expect(sut.activeWorkout?.start, liveStart);
    expect(sut.activeWorkout?.end, isNull);
    expect(sut.history.map((each) => each.id), [saved.id], reason: 'the live one is not history');
  });

  test('without an account it stays on the device, owed to the server', () async {
    access.account = false;

    final saved = await sut.logWorkout(past());

    verify(local.finishWorkout(any, 'u1')).called(1);
    verifyNever(remote.saveWorkout(any));
    expect(saved.synced, isFalse);
    expect(sut.history.map((each) => each.id), [saved.id]);
  });

  test('a refused send keeps the device copy', () async {
    when(remote.saveWorkout(any)).thenThrow(Exception('offline'));

    final saved = await sut.logWorkout(past());

    verify(local.finishWorkout(any, 'u1')).called(1);
    verifyNever(local.storeWorkoutHistory(any, any));
    expect(sut.history.map((each) => each.id), [saved.id]);
  });

  test('it is counted as logged, not finished, with what history keeps', () async {
    await sut.logWorkout(past());

    final logged = reported.parametersOf('workout_logged');
    expect(logged['exercise_count'], 1);
    expect(logged['set_count'], 1);
    expect(logged['duration_min'], end.difference(start).inMinutes);
    expect(reported.names, isNot(contains('workout_finished')));
  });
}
