// The records a workout set, placed on the sets that set them (#F20).
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart_models/heart_models.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  Workout session() {
    final light = ExerciseSet(bench, weight: 80, reps: 8)..isCompleted = true;
    final heavy = ExerciseSet(bench, weight: 105, reps: 3)..isCompleted = true;
    return Workout.fromExercises([WorkoutExercise(starter: light)..add(heavy)]);
  }

  test('a beaten record lands on the set whose values it holds', () {
    final workout = session();
    final heavy = workout.first.last;
    final marks = recordMarks(workout, [
      (
        exercise: bench,
        kind: RecordKind.maxWeight,
        record: {
          'weight': 105.0,
          'reps': 3,
          'workoutId': workout.id,
          'previous': {'weight': 100.0, 'reps': 3},
        },
      ),
    ]);

    expect(marks, {
      heavy.id: [RecordKind.maxWeight],
    });
  });

  test("an exercise's first time marks nothing: every record would fall at once", () {
    final workout = session();
    final marks = recordMarks(workout, [
      (exercise: bench, kind: RecordKind.maxWeight, record: {'weight': 105.0, 'reps': 3, 'workoutId': workout.id}),
    ]);

    expect(marks, isEmpty);
  });

  test('several records on one set stay on that one set', () {
    final workout = session();
    final heavy = workout.first.last;
    final beaten = {'previous': <String, Object>{}};
    final marks = recordMarks(workout, [
      (exercise: bench, kind: RecordKind.maxWeight, record: {'weight': 105.0, 'reps': 3, ...beaten}),
      (exercise: bench, kind: RecordKind.oneRepMax, record: {'value': 111.0, 'weight': 105.0, 'reps': 3, ...beaten}),
    ]);

    expect(marks, {
      heavy.id: [RecordKind.maxWeight, RecordKind.oneRepMax],
    });
  });
}
