import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'mocks.mocks.dart';
import 'utils.dart';

void main() {
  const exercisesTable = 'exercises';
  const syncsTable = 'syncs';
  final db = MockDatabase();
  final txn = MockTransaction();
  late LocalDatabase local;

  setUp(
    () async {
      local = await LocalDatabase.init(other: db);

      when(
        db.transaction<(DateTime?, Iterable<Exercise>)>(
          argThat(isA<Future<(DateTime?, Iterable<Exercise>)> Function(Transaction)>()),
          exclusive: anyNamed('exclusive'),
        ),
      ).thenAnswer(
        (invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<(DateTime?, Iterable<Exercise>)> Function(Transaction);
          return await callback(txn);
        },
      );
    },
  );

  test(
    'should return exercises and parsed syncedAt if sync row exists',
    () async {
      final now = DateTime.parse('2023-01-01T00:00:00.000');
      final rawExercise = exercise(name: 'Push Up');
      final rawRow = rawExercise.toMap().map((k, v) => MapEntry(k.toSnake(), v));

      when(txn.query('exercises')).thenAnswer((_) async => [rawRow]);

      when(
        txn.query(
          syncsTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer(
        (_) async => [
          {'table_name': exercisesTable, 'synced_at': now.toIso8601String()},
        ],
      );

      final (syncedAt, exercises) = await local.getExercises();

      expect(syncedAt, now);
      expect(exercises.length, 1);
      expect(exercises.first.name, 'Push Up');
    },
  );

  test(
    'should return null syncedAt if sync row is missing',
    () async {
      final ex = exercise(name: 'Squat');
      final row = ex.toMap().map((k, v) => MapEntry(k.toSnake(), v));

      when(txn.query('exercises')).thenAnswer((_) async => [row]);
      when(
        txn.query(
          syncsTable,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => []);

      final (syncedAt, exercises) = await local.getExercises();

      expect(syncedAt, isNull);
      expect(exercises.length, 1);
      expect(exercises.first.name, 'Squat');
    },
  );

  test(
    'should return empty exercise list if table is empty',
    () async {
      when(txn.query('exercises')).thenAnswer((_) async => []);
      when(txn.query(syncsTable, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
          .thenAnswer((_) async => []);

      final (syncedAt, exercises) = await local.getExercises();

      expect(syncedAt, isNull);
      expect(exercises, isEmpty);
    },
  );

  test(
    'should return null syncedAt if timestamp is malformed',
    () async {
      final ex = exercise(name: 'Lunge');
      final row = ex.toMap().map((k, v) => MapEntry(k.toSnake(), v));

      when(txn.query('exercises')).thenAnswer((_) async => [row]);
      when(txn.query(syncsTable, where: anyNamed('where'), whereArgs: anyNamed('whereArgs'))).thenAnswer((_) async => [
            {'table_name': exercisesTable, 'synced_at': 'not-a-date'},
          ],);

      final (syncedAt, exercises) = await local.getExercises();

      expect(syncedAt, isNull);
      expect(exercises.length, 1);
    },
  );

  test(
    'should throw if database query throws',
    () async {
      when(txn.query(any)).thenThrow(Exception('DB failed'));

      expect(() => local.getExercises(), throwsException);
    },
  );
}
