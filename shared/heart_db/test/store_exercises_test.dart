import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
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
      // the mocks are shared across the group, so recorded calls would otherwise
      // accumulate and every `called(n)` would count its predecessors' calls too.
      clearInteractions(db);
      clearInteractions(txn);
      clearInteractions(batch);

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
      expectedRow['muscles'] = jsonEncode(testExercise.muscles.toMap());

      await local.storeExercises([testExercise]);

      verify(
        batch.rawInsert(
          any,
          any,
        ),
      ).called(1);

      verify(
        txn.rawInsert(
          argThat(contains('INSERT INTO $expectedSyncTable')),
          [expectedTable, null],
        ),
      ).called(1);

      verify(batch.commit(noResult: true)).called(1);
    },
  );

  test(
    'should encode the movement blob rather than binding a map',
    () async {
      // `Exercise.toMap()` emits `movement` as a nested map, which sqflite
      // cannot bind and the `exercises` table has no column for until v5.
      final testExercise = exercise(name: 'Push Up', movement: pushUpMovement);

      await local.storeExercises([testExercise]);

      final captured = verify(batch.rawInsert(captureAny, captureAny)).captured;
      final [String statement, List<Object?> values] = captured;

      expect(statement, contains('movement'));
      expect(values, contains(jsonEncode(testExercise.movement.toMap())));
      expect(values.whereType<Map>(), isEmpty);
    },
  );

  test(
    'should encode an absent movement as an empty blob',
    () async {
      final testExercise = exercise(name: 'Push Up');

      await local.storeExercises([testExercise]);

      final captured = verify(batch.rawInsert(captureAny, captureAny)).captured;
      final [String statement, List<Object?> values] = captured;

      expect(statement, contains('movement'));
      expect(values, contains(jsonEncode(Movement.empty().toMap())));
    },
  );

  test(
    'should handle multiple exercises correctly',
    () async {
      final exercises = [exercise(name: 'Squat'), exercise(name: 'Lunge')];

      await local.storeExercises(exercises);

      verify(
        batch.rawInsert(
          any,
          any,
        ),
      ).called(2);

      verify(
        txn.rawInsert(
          argThat(contains('INSERT INTO $expectedSyncTable')),
          [expectedTable, null],
        ),
      ).called(1);

      verify(batch.commit(noResult: true)).called(1);
    },
  );

  test(
    'should update sync table even with an empty exercise list',
    () async {
      await local.storeExercises([]);

      verifyNever(batch.rawInsert(any, any));

      verify(
        txn.rawInsert(
          argThat(contains('INSERT INTO $expectedSyncTable')),
          [expectedTable, null],
        ),
      ).called(1);

      verify(batch.commit(noResult: true)).called(1);
    },
  );

  test(
    'should write validated unconditionally so a demoted flag clears',
    () async {
      // `toMap()` omits a null flag, and the conflict-update leaves absent
      // keys stale — a row going library → custom would keep its old mark.
      Object? boundValidated(String statement, List<Object?> values) {
        final columns = RegExp(r'\(([^)]*)\)').firstMatch(statement)!.group(1)!.split(',');
        return values[columns.indexWhere((column) => column.trim() == 'validated')];
      }

      await local.storeExercises([exercise(name: 'Push Up')]);

      var [String statement, List<Object?> values] = verify(batch.rawInsert(captureAny, captureAny)).captured;
      expect(boundValidated(statement, values), isNull);

      await local.storeExercises([exercise(name: 'Push Up', validated: false)]);

      [statement, values] = verify(batch.rawInsert(captureAny, captureAny)).captured;
      expect(boundValidated(statement, values), 0);
    },
  );

  test(
    'should record the locale the catalog was fetched under',
    () async {
      await local.storeExercises([exercise()], locale: 'ru');

      verify(
        txn.rawInsert(
          argThat(contains('INSERT INTO $expectedSyncTable')),
          [expectedTable, 'ru'],
        ),
      ).called(1);
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
