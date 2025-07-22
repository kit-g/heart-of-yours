import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'mocks.mocks.dart';
import 'utils.dart';

void main() {
  final db = MockDatabase();
  final txn = MockTransaction();
  final batch = MockBatch();
  late LocalDatabase local;

  const expectedTable = 'exercises';
  const expectedSyncTable = 'syncs';

  setUp(
    () async {
      local = await LocalDatabase.init(other: db);

      when(
        db.transaction<void>(
          argThat(isA<Future<void> Function(Transaction)>()),
          exclusive: anyNamed('exclusive'),
        ),
      ).thenAnswer(
        (invocation) async {
          final callback = invocation.positionalArguments.first as Future<void> Function(Transaction);
          await callback(txn);
        },
      );

      when(txn.batch()).thenReturn(batch);
      when(batch.commit(noResult: anyNamed('noResult'))).thenAnswer((_) async => []);
    },
  );

  test(
    'should insert one exercise and a sync row',
    () async {
      final testExercise = exercise(name: 'Push Up');
      final expectedRow = testExercise.toMap().map((key, value) => MapEntry(key.toSnake(), value));

      await local.storeExercises([testExercise]);

      verify(
        batch.insert(
          expectedTable,
          expectedRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);

      verify(
        txn.insert(
          expectedSyncTable,
          {'table_name': expectedTable},
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);

      verify(batch.commit(noResult: true)).called(1);
    },
  );

  test(
    'should handle multiple exercises correctly',
    () async {
      final exercises = [exercise(name: 'Squat'), exercise(name: 'Lunge')];

      await local.storeExercises(exercises);

      verify(
        batch.insert(
          expectedTable,
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(2);

      verify(
        txn.insert(
          expectedSyncTable,
          {'table_name': expectedTable},
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);

      verify(batch.commit(noResult: true)).called(1);
    },
  );

  test(
    'should update sync table even with an empty exercise list',
    () async {
      await local.storeExercises([]);

      verifyNever(batch.insert(any, any));

      verify(
        txn.insert(
          expectedSyncTable,
          {'table_name': expectedTable},
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ).called(1);

      verify(batch.commit(noResult: true)).called(1);
    },
  );

  test(
    'should throw an exception when batch commit fails',
    () async {
      when(batch.commit(noResult: true)).thenThrow(Exception('DB commit failed'));

      expect(
        () => local.storeExercises([exercise()]),
        throwsException,
      );
    },
  );
}

