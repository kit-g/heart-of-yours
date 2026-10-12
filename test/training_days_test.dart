import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/home_widgets.dart';
import 'package:heart/core/utils/training_days.dart';
import 'package:heart_models/heart_models.dart';

final _bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
final _pullUp = Exercise(name: 'Pull-up', category: .repsOnly, target: .back);
final _run = Exercise(name: 'Running', category: .cardio, target: .cardio);

/// A workout started at [start] and finished [minutes] later.
Workout _workout(DateTime start, {int minutes = 60, void Function(Workout)? sets}) {
  final workout = Workout(name: 'Session')..start = start;
  sets?.call(workout);
  workout.finish(start.add(Duration(minutes: minutes)));
  return workout;
}

ExerciseSet _done(Exercise exercise, {double? weight, int? reps, SetType type = .normal}) {
  return ExerciseSet(exercise, weight: weight, reps: reps)
    ..isCompleted = true
    ..setType = type;
}

void main() {
  final since = DateTime(2026, 7, 1);

  test('a day adds up its workouts: volume, time, sets and reps', () {
    final days = trainingDays(
      [
        _workout(
          DateTime(2026, 10, 12, 7),
          minutes: 45,
          sets: (workout) => workout.add(_bench)
            ..add(_done(_bench, weight: 60, reps: 5))
            ..add(_done(_bench, weight: 70, reps: 3)),
        ),
        _workout(
          DateTime(2026, 10, 12, 18),
          minutes: 30,
          sets: (workout) => workout.add(_pullUp).add(_done(_pullUp, reps: 10)),
        ),
      ],
      since: since,
    );

    expect(days, {
      DateTime(2026, 10, 12): (volume: 510.0, workouts: 2, seconds: 75 * 60, sets: 3, reps: 18),
    });
  });

  test('warm-ups and unticked sets are not the work', () {
    final days = trainingDays(
      [
        _workout(
          DateTime(2026, 10, 12, 7),
          sets: (workout) => workout.add(_bench)
            ..add(_done(_bench, weight: 40, reps: 10, type: .warmup))
            ..add(ExerciseSet(_bench, weight: 100, reps: 5))
            ..add(_done(_bench, weight: 60, reps: 5)),
        ),
      ],
      since: since,
    );

    expect(days.values.single, (volume: 300.0, workouts: 1, seconds: 3600, sets: 1, reps: 5));
  });

  test('volume is weight × reps of the loaded categories only', () {
    final days = trainingDays(
      [
        _workout(
          DateTime(2026, 10, 12, 7),
          sets: (workout) {
            workout.add(_pullUp).add(_done(_pullUp, reps: 12));
            workout.add(_run).add(_done(_run));
          },
        ),
      ],
      since: since,
    );

    expect(days.values.single.volume, 0);
    expect(days.values.single.sets, 2);
  });

  test('a workout belongs to the local day it started, and the window leaves older ones out', () {
    final days = trainingDays(
      [
        _workout(DateTime(2026, 10, 11, 23, 30), minutes: 90),
        _workout(DateTime(2026, 6, 30, 12)),
      ],
      since: since,
    );

    expect(days.keys, [DateTime(2026, 10, 11)]);
  });

  test('an unfinished workout counts for nothing', () {
    final active = Workout(name: 'Now')..start = DateTime(2026, 10, 12, 7);

    expect(trainingDays([active], since: since), isEmpty);
  });

  test('the snapshot carries days by date, the unit and the accent', () {
    final snapshot = TrainingSnapshot(
      days: {DateTime(2026, 10, 2): (volume: 1234.56, workouts: 1, seconds: 3000, sets: 12, reps: 96)},
      unit: .imperial,
      accent: 0xFF112233,
      accentDark: 0xFF445566,
    );

    expect(snapshot.toMap(), {
      'version': 1,
      'unit': 'imperial',
      'accent': 0xFF112233,
      'accentDark': 0xFF445566,
      'days': {
        '2026-10-02': [1234.6, 1, 3000, 12, 96],
      },
    });
  });
}
