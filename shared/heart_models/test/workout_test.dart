import 'package:heart_models/heart_models.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'workout_test.mocks.dart';

@GenerateMocks([Exercise])
void main() {
  group(
    'ExerciseSet Tests',
    () {
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
}
