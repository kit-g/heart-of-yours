import 'package:test/test.dart';
import 'package:heart_models/heart_models.dart';

const _json = {
  'direction': 'Push',
  'exercise': 'Bench Press',
  'joint': 'Shoulder',
  'level': 'Intermediate',
  'modality': 'Strength',
  'muscleGroup': 'Chest',
  'ulc': 'bench-press',
};

void main() {
  group(
    'ExerciseDirection Tests',
    () {
      test(
        'fromString returns correct enum value',
        () {
          expect(ExerciseDirection.fromString('Push'), ExerciseDirection.push);
          expect(ExerciseDirection.fromString('Pull'), ExerciseDirection.pull);
          expect(ExerciseDirection.fromString('Static'), ExerciseDirection.static);
          expect(ExerciseDirection.fromString('Invalid'), ExerciseDirection.other);
          expect(ExerciseDirection.fromString(null), ExerciseDirection.other);
        },
      );
    },
  );

  group(
    'Exercise Tests',
    () {
      test(
        'fromJson creates Exercise instance',
        () {
          final exercise = Exercise.fromJson(_json);

          expect(exercise.direction, ExerciseDirection.push);
          expect(exercise.name, 'Bench Press');
          expect(exercise.joint, 'Shoulder');
          expect(exercise.level, 'Intermediate');
          expect(exercise.modality, 'Strength');
          expect(exercise.muscleGroup, 'Chest');
          expect(exercise.ulc, 'bench-press');
        },
      );

      test(
        'contains checks for query match',
        () {
          final exercise = Exercise.fromJson(_json);

          expect(exercise.contains('bench'), true);
          expect(exercise.contains('Bench'), true);
          expect(exercise.contains('Press'), true);
          expect(exercise.contains(' Press'), true);
          expect(exercise.contains(' press'), true);
          expect(exercise.contains(' press '), true);
        },
      );

      test(
        'toMap converts Exercise to a map',
        () {
          final exercise = Exercise.fromJson(_json);

          final map = exercise.toMap();
          expect(map, _json);
        },
      );

      test(
        'Equality works correctly',
        () {
          final exercise1 = Exercise.fromJson(
            _json,
          );

          final exercise2 = Exercise.fromJson(_json);

          final exercise3 = Exercise.fromJson(
            {
              'direction': 'Pull',
              'exercise': 'Pull Up',
              'joint': 'Elbow',
              'level': 'Advanced',
              'modality': 'Strength',
              'muscleGroup': 'Back',
              'ulc': 'pull-up',
            },
          );

          expect(exercise1 == exercise2, true);
          expect(exercise1.hashCode == exercise2.hashCode, true);

          expect(exercise1 == exercise3, false);
          expect(exercise1.hashCode == exercise3.hashCode, false);
        },
      );
    },
  );
}
