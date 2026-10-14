import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Supersets and circuits (#159): a group is a run of neighbours sharing a
/// label, and the round goes member by member before it rests.
void main() {
  WorkoutExercise block(String name, int sets, {int? superset}) {
    final lift = Exercise(name: name, category: .barbell, target: .chest);
    final block = WorkoutExercise(starter: ExerciseSet(lift))..superset = superset;
    for (final _ in Iterable.generate(sets - 1)) {
      block.add(ExerciseSet(lift));
    }
    return block;
  }

  List<int?> labels(Iterable<WorkoutExercise> exercises) => [for (final each in exercises) each.superset];

  group('grouping', () {
    test('two neighbours make a superset under the lowest free label', () {
      final row = block('Row', 3, superset: 1);
      final curl = block('Curl', 3, superset: 1);
      final press = block('Press', 3);
      final dip = block('Dip', 3);
      final workout = Workout.fromExercises([row, curl, press, dip], name: 'Pull');

      final changed = workout.group(press, dip);

      expect(labels(workout), [1, 1, 2, 2]);
      expect(changed, {press, dip});
      expect(workout.groupOf(press), [press, dip]);
    });

    test("joining a group's neighbour makes a circuit", () {
      final row = block('Row', 3, superset: 1);
      final curl = block('Curl', 3, superset: 1);
      final press = block('Press', 3);
      final workout = Workout.fromExercises([row, curl, press], name: 'Pull');

      workout.group(press, curl);

      expect(labels(workout), [1, 1, 1]);
      expect(workout.groupOf(row), hasLength(3));
    });

    test('two groups joined become one', () {
      final exercises = [
        block('A', 1, superset: 1),
        block('B', 1, superset: 1),
        block('C', 1, superset: 2),
        block('D', 1, superset: 2),
      ];
      exercises.group(exercises[1], exercises[2]);
      expect(labels(exercises), [1, 1, 1, 1]);
    });

    test('leaving a pair leaves no group at all', () {
      final row = block('Row', 3, superset: 1);
      final curl = block('Curl', 3, superset: 1);
      final workout = Workout.fromExercises([row, curl], name: 'Pull');

      final changed = workout.leave(row);

      expect(labels(workout), [null, null]);
      expect(changed, {row, curl});
    });

    test('leaving the middle of a circuit splits it', () {
      final exercises = [
        for (final name in ['A', 'B', 'C', 'D', 'E']) block(name, 1, superset: 1),
      ];
      exercises.leave(exercises[2]);
      expect(labels(exercises), [1, 1, null, 2, 2]);
    });

    test('dropped between two members, an exercise joins them', () {
      final exercises = [block('A', 1, superset: 1), block('X', 1), block('B', 1, superset: 1)];
      exercises.settle(moved: exercises[1]);
      expect(labels(exercises), [1, 1, 1]);
    });

    test('dragged away from its group, a member leaves it', () {
      final exercises = [
        block('A', 1, superset: 1),
        block('B', 1, superset: 1),
        block('X', 1),
        block('C', 1, superset: 1),
      ];
      exercises.settle(moved: exercises[3]);
      expect(labels(exercises), [1, 1, null, null]);
    });

    test('the same label in two runs reads as two groups', () {
      final exercises = [
        block('A', 1, superset: 1),
        block('B', 1, superset: 1),
        block('X', 1),
        block('C', 1, superset: 1),
        block('D', 1, superset: 1),
      ];
      exercises.settle();
      expect(labels(exercises), [1, 1, null, 2, 2]);
    });

    test('a label alone is no group', () {
      final lone = block('A', 1, superset: 4);
      final workout = Workout.fromExercises([lone, block('B', 1)], name: 'W');
      expect(workout.groupOf(lone), [lone]);
      workout.settle();
      expect(lone.superset, isNull);
    });
  });

  group('the round', () {
    late WorkoutExercise row;
    late WorkoutExercise curl;
    late WorkoutExercise press;
    late Workout workout;

    setUp(() {
      row = block('Row', 2, superset: 1);
      curl = block('Curl', 2, superset: 1);
      press = block('Press', 2);
      workout = Workout.fromExercises([row, curl, press], name: 'Pull');
    });

    test('goes on to the next member, and rests only after the last', () {
      row.first.isCompleted = true;
      expect(workout.restOfRound(row), [curl]);
      expect(workout.restsAs(row), isNull);
      expect(workout.nextInGroup(row), (curl, curl.first));

      curl.first.isCompleted = true;
      expect(workout.restsAs(curl), curl);
      expect(workout.nextInGroup(curl), (row, row.last));
    });

    test('a member with nothing left closes the round early, resting as the last', () {
      for (final set in curl) {
        set.isCompleted = true;
      }
      row.first.isCompleted = true;
      expect(workout.restsAs(row), curl);
      expect(workout.nextInGroup(row), (row, row.last));
    });

    test('an exercise on its own rests as itself and has no group order', () {
      expect(workout.restsAs(press), press);
      expect(workout.nextInGroup(press), isNull);
    });

    test('a finished group has nothing next of its own', () {
      for (final set in [...row, ...curl]) {
        set.isCompleted = true;
      }
      expect(workout.nextInGroup(curl), isNull);
    });
  });
}
