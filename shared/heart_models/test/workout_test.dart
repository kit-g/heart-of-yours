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
      when(mockExercise.category).thenReturn(Category.weightedBodyWeight);
      when(mockExercise.target).thenReturn(Target.chest);
    },
  );

  ExerciseSet setFactory({int reps = 10, double weight = 50, bool isCompleted = false}) {
    return ExerciseSet(
      mockExercise,
      start: DateTime.now(),
      reps: reps,
      weight: weight,
    )..isCompleted = isCompleted;
  }

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
                'id': startTime.toIso8601String(),
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
          starterSet = setFactory();
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

          expect(workoutExercise.isStarted, isTrue);
        },
      );
    },
  );
  group(
    'Workout Tests',
    () {
      late ExerciseSet starterSet;
      late ExerciseSet completedSet;
      late WorkoutExercise workoutExercise;
      late Workout workout;

      setUp(
        () {
          starterSet = setFactory();
          completedSet = setFactory(reps: 8, weight: 60, isCompleted: true);
          workoutExercise = WorkoutExercise(starter: starterSet);

          workout = Workout(name: 'Mock Workout');
        },
      );

      test(
        'Workout is initialized with a name',
        () {
          expect(workout.name, equals('Mock Workout'));
          expect(workout.isCompleted, isFalse);
          expect(workout.duration, isNull);
          expect(workout.total, isNull);
          expect(workout.isStarted, isFalse);
          expect(workout.isValid, isFalse);
          expect(workout.end, isNull);
        },
      );

      test(
        'Appending a WorkoutExercise adds it to the workout',
        () {
          workout.append(workoutExercise);

          expect(workout.sets.length, equals(1));
          expect(workout.sets, contains(workoutExercise));
        },
      );

      test(
        'Removing a WorkoutExercise updates the workout',
        () {
          workout.append(workoutExercise);
          workout.remove(workoutExercise);

          expect(workout.sets, isEmpty);
        },
      );

      test(
        'Workout total calculates correctly',
        () {
          final additionalSet = ExerciseSet(
            mockExercise,
            reps: 12,
            weight: 60.0,
            start: DateTime.now(),
          );

          final additionalExercise = WorkoutExercise(starter: additionalSet);

          workout.append(workoutExercise);
          workout.append(additionalExercise);

          expect(workout.total, equals(workoutExercise.total! + additionalExercise.total!));
        },
      );

      test(
        'Marking a workout as complete sets end time and isCompleted',
        () {
          final endTime = DateTime.now();

          workout.finish(endTime);

          expect(workout.end, equals(endTime));
          expect(workout.isCompleted, isTrue);
        },
      );

      test(
        'Duration is calculated correctly after workout is finished',
        () {
          final startTime = DateTime.now();
          final endTime = startTime.add(const Duration(hours: 1));

          workout.finish(endTime);

          expect(workout.duration?.inSeconds, equals(3600));
        },
      );

      test(
        'isStarted returns true if at least one set is completed',
        () {
          workout.append(workoutExercise);
          workoutExercise.add(completedSet);
          expect(workout.isStarted, equals(true));
        },
      );

      test(
        'isStarted returns false if no sets are completed',
        () {
          workout.append(workoutExercise);

          expect(workout.isStarted, equals(false));
        },
      );

      test(
        'isValid returns true if all sets are completed',
        () async {
          expect(workout.isEmpty, isTrue);

          for (var _ in List.generate(5, (_) => 1)) {
            var exercise = WorkoutExercise(starter: starterSet);
            workout.append(exercise);
            await 10.milliseconds;
          }

          expect(workout.isValid, equals(false)); // Not all sets are complete yet.

          for (var exercise in workout) {
            for (var set in exercise) {
              set.isCompleted = true;
            }
          }

          expect(workout.isValid, equals(true));
        },
      );

      test(
        'startExercise adds a new exercise to the workout',
        () {
          workout.add(mockExercise);

          expect(workout.sets.length, equals(1));
          expect(workout.sets.first.exercise, equals(mockExercise));
        },
      );

      test(
        'swap reorders exercises correctly',
        () {
          final secondExercise = WorkoutExercise(
            starter: ExerciseSet(
              mockExercise,
              reps: 15,
              weight: 40.0,
              start: DateTime.now(),
            ),
          );

          workout.append(workoutExercise);
          workout.append(secondExercise);

          workout.swap(secondExercise, workoutExercise);

          final exercises = workout.sets.toList();
          expect(exercises.first, equals(secondExercise));
          expect(exercises.last, equals(workoutExercise));
        },
      );

      test(
        'nextIncomplete returns the next incomplete set and exercise',
        () {
          workout.append(workoutExercise);

          workoutExercise.add(completedSet);

          final next = workout.nextIncomplete(workoutExercise, completedSet);

          expect(next, isNotNull);
          expect(next!.$2.isCompleted, equals(false));
        },
      );

      test(
        'toSummary creates a valid summary',
        () {
          workout.append(workoutExercise);

          final summary = workout.toSummary();

          expect(summary.id, equals(workout.id));
          expect(summary.name, equals(workout.name));
        },
      );
    },
  );
}

extension on int {
  Future<void> get milliseconds {
    return Future.delayed(Duration(milliseconds: this));
  }
}
