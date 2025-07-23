import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  late LocalDatabase local;
  final db = MockDatabase();

  const table = 'exercise_details';
  const userId = 'user-1';

  setUp(
    () async {
      reset(db);
      local = await LocalDatabase.init(other: db);
    },
  );

  test(
    'returns rest timers as a Map<String, int>',
    () async {
      final mockRows = [
        {'exercise_name': 'Push Up', 'rest_timer': 30},
        {'exercise_name': 'Squat', 'rest_timer': 45},
      ];

      when(
        db.query(
          table,
          columns: ['exercise_name', 'rest_timer'],
          where: 'user_id = ? AND rest_timer IS NOT NULL',
          whereArgs: [userId],
        ),
      ).thenAnswer((_) async => mockRows);

      final result = await local.getTimers(userId);

      expect(
        result.length,
        equals(2),
      );
      expect(
        result['Push Up'],
        equals(30),
      );
      expect(
        result['Squat'],
        equals(45),
      );
    },
  );

  test(
    'returns empty map when no timers exist',
    () async {
      when(
        db.query(
          table,
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => []);

      final result = await local.getTimers(userId);
      expect(result, isEmpty);
    },
  );

  test(
    'queries with correct parameters',
    () async {
      when(
        db.query(
          any,
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => []);

      await local.getTimers(userId);

      verify(
        db.query(
          table,
          columns: ['exercise_name', 'rest_timer'],
          where: 'user_id = ? AND rest_timer IS NOT NULL',
          whereArgs: [userId],
        ),
      ).called(1);
    },
  );
}
