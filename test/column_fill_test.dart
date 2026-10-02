import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/column_fill.dart';
import 'package:heart_models/heart_models.dart';

/// What a set table's header writes into its column (#225).
void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final run = Exercise(name: 'Muffin Run', category: .cardio, target: .other);

  /// Three sets of [exercise]; the first carries [weight] and [reps], if given.
  WorkoutExercise three(Exercise exercise, {double? weight, int? reps}) {
    return WorkoutExercise(
        starter: ExerciseSet(exercise, weight: weight, reps: reps),
      )
      ..add(ExerciseSet(exercise))
      ..add(ExerciseSet(exercise));
  }

  test('each set takes its own value from last time', () {
    final sets = three(bench);
    final last = [
      {'weight': 60, 'reps': 8},
      {'weight': 62.5, 'reps': 6},
      {'weight': 65, 'reps': 5},
    ];

    final fill = columnFill(sets, .weight, previous: (index) => last.elementAtOrNull(index));
    expect(fill.values, [60, 62.5, 65]);
  });

  test("without last time, the top set's value", () {
    final sets = three(bench, weight: 70, reps: 5);

    final fill = columnFill(sets, .reps, previous: (_) => null);
    expect(fill.values, [5, 5, 5]);
  });

  test('last time where there is one, the top set past it', () {
    final sets = three(bench, weight: 70, reps: 5);
    final last = [
      {'weight': 60, 'reps': 8},
    ];

    final fill = columnFill(sets, .weight, previous: (index) => last.elementAtOrNull(index));
    expect(fill.values, [60, 70, 70]);
  });

  test('neither, and nothing is written', () {
    expect(columnFill(three(bench), .weight, previous: (_) => null), isEmpty);
  });

  test('a ticked set is left as it is', () {
    final sets = three(bench, weight: 70, reps: 5);
    sets.first.isCompleted = true;

    final fill = columnFill(sets, .weight, previous: (_) => null);
    expect(fill.keys, sets.skip(1));
    expect(fill.values, [70, 70], reason: 'the top set still lends its value');
  });

  test("cardio's columns go by their own keys", () {
    final sets = three(run);
    final last = [
      {'distance': 5.0, 'duration': 1500},
    ];

    expect(columnFill(sets, .duration, previous: (index) => last.elementAtOrNull(index)).values, [1500]);
    expect(columnFill(sets, .distance, previous: (index) => last.elementAtOrNull(index)).values, [5.0]);
  });

  test('each category shows its own columns', () {
    expect(SetColumn.of(.barbell), [SetColumn.weight, SetColumn.reps]);
    expect(SetColumn.of(.repsOnly), [SetColumn.reps]);
    expect(SetColumn.of(.cardio), [SetColumn.distance, SetColumn.duration]);
    expect(SetColumn.of(.duration), [SetColumn.duration]);
  });
}
