import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart_models/heart_models.dart';

/// "Next: set N" on the lock screen (#133): which set the user is about to do.
void main() {
  Exercise exercise(String name) {
    return Exercise.fromJson({
      'id': 'id-${name.toLowerCase()}',
      'name': name,
      'category': 'Barbell',
      'target': 'Chest',
      'archived': false,
    });
  }

  WorkoutExercise block(String name, int sets) {
    final lift = exercise(name);
    final block = WorkoutExercise(starter: ExerciseSet(lift));
    for (final _ in Iterable.generate(sets - 1)) {
      block.add(ExerciseSet(lift));
    }
    return block;
  }

  late WorkoutExercise bench;
  late WorkoutExercise squat;
  late Workout workout;

  setUp(() {
    bench = block('Bench', 3);
    squat = block('Squat', 2);
    workout = Workout.fromExercises([bench, squat], name: 'Push');
  });

  (WorkoutExercise, ExerciseSet) tick(WorkoutExercise exercise, int number) {
    final set = exercise.elementAt(number - 1)..isCompleted = true;
    return (exercise, set);
  }

  test('nothing ticked yet is the first set of the first exercise', () {
    final next = upNextIn(workout);

    expect(next?.exercise, same(bench));
    expect(next?.number, 1);
    expect(next?.set, same(bench.first));
  });

  test('stays on the exercise while it has sets left', () {
    tick(bench, 1);
    final after = tick(bench, 2);

    final next = upNextIn(workout, after: after);

    expect(next?.exercise, same(bench));
    expect(next?.number, 3);
  });

  test('moves to the next exercise once this one is done', () {
    tick(bench, 1);
    tick(bench, 2);
    final after = tick(bench, 3);

    final next = upNextIn(workout, after: after);

    expect(next?.exercise, same(squat));
    expect(next?.number, 1);
  });

  test('follows the user rather than the list', () {
    tick(bench, 1);
    final after = tick(squat, 1);

    final next = upNextIn(workout, after: after);

    expect(next?.exercise, same(squat), reason: 'a superset alternates; the set just done says where they are');
    expect(next?.number, 2);
  });

  test('a later exercise offers its first open set, not its first set', () {
    tick(squat, 1);
    final after = tick(bench, 3);

    final next = upNextIn(workout, after: after);

    expect(next?.exercise, same(squat));
    expect(next?.number, 2);
  });

  test('wraps to a set skipped earlier when nothing is open after the last one', () {
    tick(bench, 2);
    tick(bench, 3);
    tick(squat, 1);
    final after = tick(squat, 2);

    final next = upNextIn(workout, after: after);

    expect(next?.exercise, same(bench));
    expect(next?.number, 1);
  });

  test('everything ticked keeps the exercise worked last, with no set', () {
    for (final exercise in [bench, squat]) {
      for (final set in exercise) {
        set.isCompleted = true;
      }
    }

    final next = upNextIn(workout, after: (bench, bench.last));

    expect(next?.exercise, same(bench));
    expect(next?.set, isNull);
    expect(next?.number, 3);
  });

  test('an anchor whose exercise was removed is ignored', () {
    final after = tick(bench, 1);
    workout.remove(bench);

    final next = upNextIn(workout, after: after);

    expect(next?.exercise, same(squat));
    expect(next?.number, 1);
  });

  test('a workout with no exercises has nothing next', () {
    expect(upNextIn(Workout(name: 'Empty')), isNull);
  });
}
