import 'package:heart_models/heart_models.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'workout_test.mocks.dart';

@GenerateMocks([Exercise])
void main() {
  late MockExercise mockExercise;

  setUp(
    () {
      mockExercise = MockExercise();

      when(mockExercise.name).thenReturn('Mock Exercise');
      when(mockExercise.direction).thenReturn(ExerciseDirection.push);
      when(mockExercise.joint).thenReturn('Mock Joint');
      when(mockExercise.level).thenReturn('Beginner');
      when(mockExercise.modality).thenReturn('Mock Modality');
      when(mockExercise.muscleGroup).thenReturn('Mock Muscle');
      when(mockExercise.ulc).thenReturn('ULC123');
    },
  );

  group(
    'ExerciseSet Tests',
    () {
      test(
        'ExerciseSet is created correctly',
        () {
          final startTime = DateTime.parse('2025-01-21T12:00:00Z');
          final set = ExerciseSet(
            mockExercise,
            reps: 12,
            weight: 75.0,
            start: startTime,
          );

          expect(set.exercise, equals(mockExercise));
          expect(set.start, equals(startTime));
          expect(set.isCompleted, equals(false));
        },
      );

      test(
        'toMap works for ExerciseSet',
        () {
          final startTime = DateTime.parse('2025-01-21T12:00:00Z');
          final weightedSet = ExerciseSet(
            mockExercise,
            reps: 8,
            weight: 100.0,
            start: startTime,
          );

          final map = weightedSet.toMap();

          expect(
            map,
            equals(
              {
                'id': sanitizeId(startTime),
                'completed': false,
                'reps': 8,
                'weight': 100.0,
              },
            ),
          );
        },
      );

      test(
        'Comparison operators work for ExerciseSet',
        () {
          final set1 = ExerciseSet(mockExercise, reps: 10, weight: 50.0);
          final set2 = ExerciseSet(mockExercise, reps: 8, weight: 60.0);

          expect(set1.total! > set2.total!, equals(true));
          expect(set1.total! >= set2.total!, equals(true));

          expect(
            ExerciseSet(mockExercise, reps: 10, weight: 50.0).total! >
                ExerciseSet(mockExercise, reps: 50, weight: 10.0).total!,
            isFalse,
          );

          expect(
            ExerciseSet(mockExercise, reps: 10, weight: 50.0).total! >=
                ExerciseSet(mockExercise, reps: 50, weight: 10.0).total!,
            isTrue,
          );

          expect(
            ExerciseSet(mockExercise, reps: 10, weight: 50.0).total! <=
                ExerciseSet(mockExercise, reps: 50, weight: 10.0).total!,
            isTrue,
          );
        },
      );

      test(
        'Copy creates a new instance of ExerciseSet',
        () {
          final original = ExerciseSet(
            mockExercise,
            reps: 12,
            weight: 60.0,
            start: DateTime.parse('2025-01-21T12:00:00Z'),
          );

          final copy = original.copy();

          expect(copy.exercise, original.exercise);
          expect(copy.total, original.total);
          expect(copy.id, isNot(equals(original.id)));
          expect(identical(copy, original), isFalse);
        },
      );

      test(
        'Factory constructor creates from JSON',
        () {
          final json = {
            'id': '2025-01-21T12:00:00Z',
            'reps': 15,
            'weight': 80.0,
            'completed': true,
          };

          final exerciseSet = ExerciseSet.fromJson(mockExercise, json);

          expect(exerciseSet.exercise, equals(mockExercise));
          expect(exerciseSet.start, equals(DateTime.parse('2025-01-21T12:00:00Z')));
          expect(exerciseSet.isCompleted, equals(true));
        },
      );
    },
  );

  group(
    'WorkoutExercise Tests',
    () {
      late ExerciseSet starterSet;

      setUp(
        () {
          starterSet = ExerciseSet(
            mockExercise,
            start: DateTime.now(),
            reps: 10,
            weight: 50,
          );
        },
      );

      test(
        'WorkoutExercise is initialized with a starter set',
        () {
          final workoutExercise = WorkoutExercise(starter: starterSet);

          expect(workoutExercise.exercise, equals(mockExercise));
          expect(workoutExercise.sets, contains(starterSet));
          expect(workoutExercise.total, equals(500.0));
          expect(workoutExercise.isStarted, equals(false));
        },
      );

      test(
        'Adding a set increases the number of sets',
        () {
          final workoutExercise = WorkoutExercise(starter: starterSet);
          final anotherSet = ExerciseSet(
            mockExercise,
            reps: 8,
            weight: 60.0,
            start: DateTime.now(),
          );

          workoutExercise.add(anotherSet);

          expect(workoutExercise.sets, contains(anotherSet));
          expect(workoutExercise.total, equals(980.0)); // 500 + 480
          expect(workoutExercise.isStarted, equals(false));
        },
      );

      test(
        'Removing a set decreases the number of sets',
        () {
          final workoutExercise = WorkoutExercise(starter: starterSet);
          workoutExercise.remove(starterSet);

          expect(workoutExercise.sets, isEmpty);
          expect([null, 0.0], contains(workoutExercise.total));
        },
      );

      test(
        'Best set is calculated correctly',
        () {
          final workoutExercise = WorkoutExercise(starter: starterSet);
          final betterSet = ExerciseSet(
            mockExercise,
            reps: 12,
            weight: 55.0,
            start: DateTime.now(),
          );

          workoutExercise.add(betterSet);

          expect(workoutExercise.best, equals(betterSet));
        },
      );

      test(
        'Order can be set and retrieved',
        () {
          final workoutExercise = WorkoutExercise(starter: starterSet);

          workoutExercise.order = 1;
          expect(workoutExercise.order, equals(1));

          workoutExercise.order = null;
          expect(workoutExercise.order, isNull);
        },
      );

      test(
        'isStarted returns true when at least one set is completed',
        () {
          final workoutExercise = WorkoutExercise(starter: starterSet);
          final completedSet = ExerciseSet(
            mockExercise,
            reps: 8,
            weight: 60.0,
            start: DateTime.now(),
          )..isCompleted = true;

          workoutExercise.add(completedSet);

          expect(workoutExercise.isStarted, equals(true));
        },
      );
    },
  );
}
