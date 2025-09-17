import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_db/src/sql.dart' as sql;
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'mocks.mocks.dart';
import 'utils.dart';

void main() {
  late LocalDatabase local;
  final db = MockDatabase();
  final txn = MockTransaction();
  final batch = MockBatch();
  final ex = exercise();

  setUp(
    () async {
      reset(db);
      reset(batch);
      local = await LocalDatabase.init(other: db);

      when(
        db.transaction<void>(
          any,
          exclusive: anyNamed('exclusive'),
        ),
      ).thenAnswer(
        (invocation) async {
          final callback = invocation.positionalArguments.first as Future<void> Function(Transaction);
          await callback(txn);
        },
      );

      when(txn.batch()).thenReturn(batch);
    },
  );

  group(
    'Start workout',
    () {
      test(
        'startWorkout inserts workout, exercises, and sets correctly',
        () async {
          final testWorkout = workout(
            exercises: [
              wExercise(
                sets: [
                  ExerciseSet(
                    ex,
                    reps: 10,
                    weight: 20,
                  ),
                  ExerciseSet(
                    ex,
                    reps: 8,
                    weight: 25,
                    // isCompleted: false,
                  ),
                ],
              ),
            ],
          );

          when(
            db.transaction<void>(
              argThat(
                isA<Future<void> Function(Transaction)>(),
              ),
              exclusive: anyNamed('exclusive'),
            ),
          ).thenAnswer(
            (inv) async {
              final callback = inv.positionalArguments.first as Future<void> Function(Transaction);
              await callback(txn);
            },
          );

          when(
            batch.commit(
              noResult: anyNamed('noResult'),
            ),
          ).thenAnswer((_) async => []);

          await local.startWorkout(testWorkout, 'user-1');

          verify(
            batch.insert(
              'workouts',
              argThat(
                containsPair('id', testWorkout.id),
              ),
              conflictAlgorithm: anyNamed('conflictAlgorithm'),
            ),
          ).called(1);

          verify(
            batch.insert(
              'workout_exercises',
              argThat(
                allOf(
                  containsPair('workout_id', testWorkout.id),
                ),
              ),
              conflictAlgorithm: anyNamed('conflictAlgorithm'),
            ),
          ).called(1);

          verify(
            batch.insert(
              'sets',
              argThat(
                allOf(
                  isA<Map<String, dynamic>>(),
                  containsPair('reps', 10),
                  containsPair('weight', 20),
                  containsPair('completed', 0),
                  predicate<Map<String, dynamic>>((map) => map['id'].toString().isNotEmpty),
                ),
              ),
              conflictAlgorithm: anyNamed('conflictAlgorithm'),
            ),
          ).called(1);

          verify(
            batch.commit(noResult: true),
          ).called(1);
        },
      );
    },
  );

  group(
    'Delete workout',
    () {
      test(
        'deleteWorkout removes workout by ID',
        () async {
          const workoutId = 'workout-123';

          when(
            db.delete(
              'workouts',
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenAnswer((_) async => 1); // simulate one row deleted

          await local.deleteWorkout(workoutId);

          verify(
            db.delete(
              'workouts',
              where: 'id = ?',
              whereArgs: [workoutId],
            ),
          ).called(1);
        },
      );

      test(
        'deleteWorkout completes even if no row is deleted',
        () async {
          const workoutId = 'nonexistent-id';

          when(
            db.delete(
              any,
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenAnswer((_) async => 0); // no rows affected

          await local.deleteWorkout(workoutId);

          verify(
            db.delete(
              'workouts',
              where: 'id = ?',
              whereArgs: [workoutId],
            ),
          ).called(1);
        },
      );

      test(
        'deleteWorkout throws if database fails',
        () async {
          const workoutId = 'faulty-id';

          when(
            db.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
          ).thenThrow(MockDatabaseException());

          expect(
            () => local.deleteWorkout(workoutId),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'Finish workout',
    () {
      test(
        'finishWorkout completes successfully and calls expected queries',
        () async {
          final w = workout(finished: true); // a full workout with sets
          const userId = 'user-123';

          when(batch.commit(noResult: true)).thenAnswer((_) async => []);
          when(
            txn.update(
              any,
              any,
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenAnswer((_) async => 1);

          when(txn.rawDelete(sql.removeUnfinished, any)).thenAnswer((_) async => 1);

          await local.finishWorkout(w, userId);

          verify(batch.commit(noResult: true)).called(1);

          verify(
            txn.update(
              'workouts',
              {'end': w.end!.toIso8601String()},
              where: 'id = ?',
              whereArgs: [w.id],
            ),
          ).called(1);

          verify(txn.rawDelete(sql.removeUnfinished, [w.id])).called(1);
        },
      );

      test(
        'finishWorkout throws if batch commit fails',
        () async {
          final w = workout(finished: true);
          const userId = 'user-123';

          when(batch.commit(noResult: true)).thenThrow(Exception('fail'));

          expect(
            () => local.finishWorkout(w, userId),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'finishWorkout throws if update fails',
        () async {
          final w = workout(finished: true);
          const userId = 'user-123';

          when(batch.commit(noResult: true)).thenAnswer((_) async => []);
          when(
            txn.update(
              any,
              any,
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenThrow(MockDatabaseException());

          expect(
            () => local.finishWorkout(w, userId),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'Start exercise',
    () {
      test(
        'startExercise inserts workout_exercise and all sets',
        () async {
          const workoutId = 'w123';
          final we = wExercise(
            sets: [
              set(isCompleted: false),
              set(),
            ],
          );

          when(txn.insert(any, any)).thenAnswer((_) async => 1);
          when(batch.commit(noResult: true)).thenAnswer((_) async => []);

          await local.startExercise(workoutId, we);

          verify(
            txn.insert(
              'workout_exercises',
              {
                'workout_id': workoutId,
                'exercise_id': we.exercise.name,
                'id': we.id,
              },
            ),
          ).called(1);

          final captured = verify(
            batch.insert('sets', captureAny, conflictAlgorithm: anyNamed('conflictAlgorithm')),
          ).captured;

          expect(
            captured,
            containsAll(
              [
                containsPair('completed', 0),
                containsPair('completed', 1),
              ],
            ),
          );
          verify(batch.commit(noResult: true)).called(1);
        },
      );

      test(
        'startExercise throws if workout_exercises insert fails',
        () async {
          const workoutId = 'w123';
          final we = wExercise();

          when(txn.insert(any, any)).thenThrow(MockDatabaseException());

          expect(
            () => local.startExercise(workoutId, we),
            throwsA(isA<DatabaseException>()),
          );
        },
      );

      test(
        'startExercise throws if batch commit fails',
        () async {
          const workoutId = 'w123';
          final we = wExercise();

          when(txn.insert(any, any)).thenAnswer((_) async => 1);
          when(batch.commit(noResult: true)).thenThrow(MockDatabaseException());

          expect(
            () => local.startExercise(workoutId, we),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'addSet',
    () {
      group(
        'addSet',
        () {
          test(
            'inserts set correctly into sets table',
            () async {
              final ex = exercise(name: 'Push Up');
              final workoutExercise = wExercise(ex: ex);
              final testSet = set(reps: 10, weight: 20);

              when(
                db.insert(any, any),
              ).thenAnswer((_) async => 1);

              await local.addSet(workoutExercise, testSet);

              verify(
                db.insert(
                  'sets',
                  argThat(
                    allOf(
                      isA<Map<String, dynamic>>(),
                      containsPair('exercise_id', workoutExercise.id),
                      containsPair('reps', 10),
                      containsPair('weight', 20.0),
                      containsPair('completed', 1),
                    ),
                  ),
                ),
              ).called(1);
            },
          );

          test(
            'throws when db insert fails',
            () async {
              final workoutExercise = wExercise();
              final testSet = set();

              when(
                db.insert(any, any),
              ).thenThrow(MockDatabaseException());

              expect(
                () => local.addSet(workoutExercise, testSet),
                throwsA(isA<DatabaseException>()),
              );
            },
          );
        },
      );
    },
  );

  group(
    'Remove set',
    () {
      group(
        'removeSet',
        () {
          test(
            'removes set by ID',
            () async {
              final testSet = set();

              when(
                db.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
              ).thenAnswer((_) async => 1); // 1 row affected

              await local.removeSet(testSet);

              verify(
                db.delete(
                  'sets',
                  where: 'id = ?',
                  whereArgs: [testSet.id],
                ),
              ).called(1);
            },
          );

          test(
            'throws when db delete fails',
            () async {
              final testSet = set();

              when(
                db.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
              ).thenThrow(MockDatabaseException());

              expect(
                () => local.removeSet(testSet),
                throwsA(isA<DatabaseException>()),
              );
            },
          );
        },
      );
    },
  );

  group(
    'removeExercise',
    () {
      test(
        'removes workout exercise by ID',
        () async {
          final ex = wExercise();

          when(
            db.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
          ).thenAnswer((_) async => 1); // 1 row affected

          await local.removeExercise(ex);

          verify(
            db.delete(
              'workout_exercises',
              where: 'id = ?',
              whereArgs: [ex.id],
            ),
          ).called(1);
        },
      );

      test(
        'throws when db delete fails',
        () async {
          final ex = wExercise();

          when(
            db.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
          ).thenThrow(MockDatabaseException());

          expect(
            () => local.removeExercise(ex),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'storeMeasurements',
    () {
      test(
        'updates set measurements in sets table',
        () async {
          final testSet = set(reps: 12, weight: 22.5, duration: 75, distance: 2.0);

          when(
            db.update(
              any,
              any,
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenAnswer((_) async => 1); // 1 row updated

          await local.storeMeasurements(testSet);

          verify(
            db.update(
              'sets',
              testSet.toRow(),
              where: 'id = ?',
              whereArgs: [testSet.id],
            ),
          ).called(1);
        },
      );

      test(
        'throws when update fails',
        () async {
          final testSet = set();

          when(
            db.update(any, any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
          ).thenThrow(MockDatabaseException());

          expect(
            () => local.storeMeasurements(testSet),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'markSetAsComplete',
    () {
      test(
        'updates set with completed = 1',
        () async {
          final testSet = set(isCompleted: false); // initial state doesn't matter here

          when(
            db.update(
              any,
              any,
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenAnswer((_) async => 1);

          await local.markSetAsComplete(testSet);

          verify(
            db.update(
              'sets',
              {'completed': 1},
              where: 'id = ?',
              whereArgs: [testSet.id],
            ),
          ).called(1);
        },
      );

      test(
        'throws if update fails',
        () async {
          final testSet = set();

          when(
            db.update(any, any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
          ).thenThrow(MockDatabaseException());

          expect(
            () => local.markSetAsComplete(testSet),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'markSetAsIncomplete',
    () {
      test(
        'updates set with completed = 0',
        () async {
          final testSet = set(isCompleted: true); // initially completed

          when(
            db.update(
              any,
              any,
              where: anyNamed('where'),
              whereArgs: anyNamed('whereArgs'),
            ),
          ).thenAnswer((_) async => 1);

          await local.markSetAsIncomplete(testSet);

          verify(
            db.update(
              'sets',
              {'completed': 0},
              where: 'id = ?',
              whereArgs: [testSet.id],
            ),
          ).called(1);
        },
      );

      test(
        'throws if update fails',
        () async {
          final testSet = set();

          when(
            db.update(any, any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')),
          ).thenThrow(MockDatabaseException());

          expect(
            () => local.markSetAsIncomplete(testSet),
            throwsA(isA<DatabaseException>()),
          );
        },
      );
    },
  );

  group(
    'getActiveWorkout',
    () {
      test(
        'returns null if no active workout is found',
        () async {
          when(db.rawQuery(any, any)).thenAnswer((_) async => []);

          final result = await local.getActiveWorkout('user-1', (_) => exercise());

          expect(result, isNull);
          verify(db.rawQuery(sql.activeWorkout, ['user-1'])).called(1);
        },
      );

      test(
        'parses and returns a Workout from a single-row response',
        () async {
          final sets = [
            set(weight: 20, reps: 10),
            set(weight: 25, reps: 8),
          ];
          final we = wExercise(sets: sets);
          final w = workout(exercises: [we], finished: false);

          // simulate optimized DB row — 1 row representing full workout via join
          final row = {
            'id': w.id,
            'start': w.start.toIso8601String(),
            'end': null,
            'name': w.name,
            'exercises': jsonEncode([
              {
                'id': we.id,
                'exercise': we.exercise.name,
                'order': 0,
                'sets': sets.map((s) => s.toMap()).toList(),
              }
            ]),
          };

          when(db.rawQuery(sql.activeWorkout, ['user-1'])).thenAnswer((_) async => [row]);

          final result = await local.getActiveWorkout('user-1', (id) => we.exercise);

          expect(result, isNotNull);
          expect(result?.name, equals(w.name));
          expect(result?.toList().length, equals(1));
          expect(result?.toList().first.sets.length, equals(2));
          expect(result?.toList().first.exercise.name, equals('Push Up'));
          expect(result?.toList().first.sets.first.weight, equals(20));
          expect(result?.toList().first.sets.first.reps, equals(10));

          verify(db.rawQuery(sql.activeWorkout, ['user-1'])).called(1);
        },
      );

      test(
        'returns null if no active workout is found',
        () async {
          when(db.rawQuery(any, any)).thenAnswer((_) async => []);

          final result = await local.getActiveWorkout('user-1', (_) => exercise());

          expect(result, isNull);
        },
      );
    },
  );

  group(
    'getWorkout',
    () {
      test(
        'getWorkout returns null when no rows are returned',
        () async {
          when(db.rawQuery(any, any)).thenAnswer((_) async => []);

          final result = await local.getWorkout('user-1', 'w123', (_) => exercise());

          expect(result, isNull);
        },
      );
    },
  );

  group(
    'storeWorkoutHistory',
    () {
      test(
        'stores full workout history with exercises and sets',
        () async {
          final history = [
            workout(
              exercises: [
                wExercise(
                  sets: [set(), set(weight: 40)],
                ),
              ],
            ),
            workout(
              name: 'Evening Pump',
              exercises: [
                wExercise(
                  sets: [set(reps: 8)],
                ),
              ],
            ),
          ];

          await local.storeWorkoutHistory(history, 'user-1');

          verify(
            batch.insert(
              'workouts',
              argThat(
                allOf(
                  isA<Map<String, dynamic>>(),
                  containsPair('user_id', 'user-1'),
                  contains('start'), // timestamps are dynamic
                ),
              ),
              conflictAlgorithm: ConflictAlgorithm.replace,
            ),
          ).called(2);

          // Verify workout_exercises inserted with correct exercise names
          verify(
            batch.insert(
              'workout_exercises',
              argThat(
                containsPair('exercise_id', 'Push Up'),
              ),
              conflictAlgorithm: ConflictAlgorithm.replace,
            ),
          ).called(2); // one for each workout

          // Verify at least 3 sets were inserted
          verify(
            batch.insert(
              'sets',
              argThat(
                allOf(
                  isA<Map<String, dynamic>>(),
                  contains('exercise_id'),
                  contains('id'),
                ),
              ),
              conflictAlgorithm: ConflictAlgorithm.replace,
            ),
          ).called(
            greaterThanOrEqualTo(3),
          );

          // Verify final commit
          verify(batch.commit()).called(1);
        },
      );

      test(
        'does not insert anything if history is empty',
        () async {
          await local.storeWorkoutHistory([], 'user-1');

          verifyNever(batch.insert(any, any));
          verify(batch.commit()).called(1);
        },
      );

      test(
        'throws when batch commit fails',
        () async {
          when(batch.commit()).thenThrow(Exception('Commit failed'));

          final workouts = [
            workout(exercises: [wExercise()]),
          ];

          expect(
            () => local.storeWorkoutHistory(workouts, 'user-1'),
            throwsA(isA<Exception>()),
          );
        },
      );
    },
  );

  group(
    'getWorkoutHistory',
    () {
      test(
        'getWorkoutHistory returns parsed workout list from serialized rows',
        () async {
          const userId = 'user-1';
          const exerciseName = 'Push Up';

          final workoutId1 = DateTime(2024).toIso8601String();
          final workoutId2 = DateTime(2025).toIso8601String();

          final sets1 = [
            set(weight: 20.0, reps: 10),
          ];
          final sets2 = [
            set(weight: 25.0, reps: 8),
          ];

          final rows = [
            {
              'id': workoutId1,
              'start': workoutId1,
              'end': workoutId1,
              'name': 'AM Session',
              'exercises': jsonEncode([
                {
                  'exercise': exerciseName,
                  'id': DateTime.now().toIso8601String(),
                  'order': 0,
                  'sets': sets1.map((s) => s.toMap()).toList(),
                }
              ]),
            },
            {
              'id': workoutId2,
              'start': workoutId1,
              'end': workoutId1,
              'name': 'PM Session',
              'exercises': jsonEncode([
                {
                  'exercise': exerciseName,
                  'id': DateTime.now().toIso8601String(),
                  'order': 0,
                  'sets': sets2.map((s) => s.toMap()).toList(),
                }
              ]),
            },
          ];

          when(db.rawQuery(sql.history, [userId])).thenAnswer((_) async => rows);

          final result = await local.getWorkoutHistory(userId, (_) => exercise(name: exerciseName));

          expect(result, isNotNull);
          expect(result, hasLength(2));

          final list = result!.toList();

          expect(list[0].id, equals(workoutId1));
          expect(list[0].name, equals('AM Session'));
          expect(list[0].toList(), hasLength(1));
          expect(list[0].toList().first.sets.first.weight, equals(20.0));

          expect(list[1].id, equals(workoutId2));
          expect(list[1].name, equals('PM Session'));
          expect(list[1].toList().first.sets.first.weight, equals(25.0));

          verify(db.rawQuery(sql.history, [userId])).called(1);
        },
      );
    },
  );
}

class MockDatabaseException extends Mock implements DatabaseException {}
