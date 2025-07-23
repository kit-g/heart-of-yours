import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_db/src/sql.dart' as sql;
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'utils.dart';

void main() {
  late LocalDatabase local;
  final db = MockDatabase();
  late Exercise ex;

  setUp(
    () async {
      local = await LocalDatabase.init(other: db);
      ex = exercise();
    },
  );

  test(
    'returns ExerciseActs grouped by workoutId',
    () async {
      final act1 = exerciseAct(workoutId: 'w1', ex: ex);
      final act2 = exerciseAct(workoutId: 'w2', ex: ex);

      // Each group gets its own workoutId and name in every row
      final rows = [
        ...act1.map(
          (set) => {
            ...set.toMap().map((k, v) => MapEntry(k.toSnake(), v)),
            'workout_id': 'w1',
            'workout_name': 'Push A',
            'exercise_id': sanitizeId(act1.start!),
          },
        ),
        ...act2.map(
          (set) => {
            ...set.toMap().map((k, v) => MapEntry(k.toSnake(), v)),
            'workout_id': 'w2',
            'workout_name': 'Pull B',
            'exercise_id': sanitizeId(act2.start!),
          },
        ),
      ];

      when(db.rawQuery(sql.getExerciseHistory, [ex.name, 'user-1'])).thenAnswer((_) async => rows);

      final result = await local.getExerciseHistory('user-1', ex);

      expect(result.length, 2);

      final ids = result.map((r) => r.workoutId);
      expect(ids, containsAll(['w1', 'w2']));
    },
  );

  test(
    'returns empty list when no history found',
    () async {
      when(db.rawQuery(sql.getExerciseHistory, [ex.name, 'user-1'])).thenAnswer((_) async => []);

      final result = await local.getExerciseHistory('user-1', ex);
      expect(result, isEmpty);
    },
  );

  test(
    'calls rawQuery with correct args',
    () async {
      when(db.rawQuery(any, any)).thenAnswer((_) async => []);

      await local.getExerciseHistory('abc', ex);

      verify(db.rawQuery(sql.getExerciseHistory, [ex.name, 'abc'])).called(1);
    },
  );
}
