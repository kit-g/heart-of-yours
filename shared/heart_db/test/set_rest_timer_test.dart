import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'mocks.mocks.dart';

void main() {
  late LocalDatabase local;
  final db = MockDatabase();
  final txn = MockTransaction();

  const table = 'exercise_details';
  const exerciseName = 'Push Up';
  const userId = 'user-1';

  setUp(
    () async {
      local = await LocalDatabase.init(other: db);

      when(
        db.transaction<void>(
          argThat(
            isA<Future<void> Function(Transaction)>(),
          ),
          exclusive: anyNamed('exclusive'),
        ),
      ).thenAnswer(
        (invocation) async {
          final callback = invocation.positionalArguments.first as Future<void> Function(Transaction);
          await callback(txn);
        },
      );
    },
  );

  test(
    'updates rest_timer when entry exists',
    () async {
      when(
        txn.query(
          table,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => [{}]); // simulate existing entry

      await local.setRestTimer(exerciseName: exerciseName, userId: userId, seconds: 90);

      verify(
        txn.update(
          table,
          {'rest_timer': 90},
          where: 'exercise_name = ? AND user_id = ?',
          whereArgs: [exerciseName, userId],
        ),
      ).called(1);

      verifyNever(
        txn.insert(any, any),
      );
    },
  );

  test(
    'inserts new rest_timer when entry does not exist',
    () async {
      when(
        txn.query(
          table,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => []); // simulate no entry

      await local.setRestTimer(exerciseName: exerciseName, userId: userId, seconds: 60);

      verify(
        txn.insert(
          table,
          {
            'rest_timer': 60,
            'exercise_name': exerciseName,
            'user_id': userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);

      verifyNever(
        txn.update(any, any),
      );
    },
  );

  test(
    'allows null seconds value',
    () async {
      when(
        txn.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => []);

      await local.setRestTimer(exerciseName: exerciseName, userId: userId, seconds: null);

      verify(
        txn.insert(
          table,
          {
            'rest_timer': null,
            'exercise_name': exerciseName,
            'user_id': userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);
    },
  );
}
