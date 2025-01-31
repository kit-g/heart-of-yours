import 'package:test/test.dart';
import 'package:heart_models/heart_models.dart';

const _json = {
  'category': 'Weighted Body Weight',
  'name': 'Bench Press',
  'target': 'Chest',
};

void main() {
  group(
    'Exercise Tests',
    () {
      test(
        'fromJson creates Exercise instance',
        () {
          final exercise = Exercise.fromJson(_json);

          expect(exercise.name, 'Bench Press');
          expect(exercise.target.value, 'Chest');
          expect(exercise.category.value, 'Weighted Body Weight');
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
              'category': 'Weighted Body Weight',
              'name': 'Squat',
              'target': 'Legs',
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
