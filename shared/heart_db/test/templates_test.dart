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

  setUp(
    () async {
      local = await LocalDatabase.init(other: db);

      when(
        db.transaction<Template>(
          any,
          exclusive: anyNamed('exclusive'),
        ),
      ).thenAnswer(
        (invocation) {
          final callback = invocation.positionalArguments.first as Future<Template> Function(Transaction);
          return callback(txn);
        },
      );
    },
  );

  when(txn.batch()).thenReturn(batch);

  group(
    'getTemplates',
    () {
      const sampleQuery = sql.getSampleTemplates;
      const userQuery = sql.getTemplates;

      test(
        'returns empty list when query yields no rows (user templates)',
        () async {
          const userId = 'user-1';

          when(db.rawQuery(userQuery, [userId])).thenAnswer((_) async => []);

          final result = await local.getTemplates(userId, (_) => exercise());

          expect(result, isEmpty);
          verify(db.rawQuery(userQuery, [userId])).called(1);
        },
      );

      test(
        'returns empty list when query yields no rows (sample templates)',
        () async {
          when(db.rawQuery(sampleQuery, null)).thenAnswer((_) async => []);

          final result = await local.getTemplates(null, (_) => exercise());

          expect(result, isEmpty);
          verify(db.rawQuery(sampleQuery, null)).called(1);
        },
      );

      test(
        'parses single-row template correctly (user template)',
        () async {
          const userId = 'user-1';
          final we = wExercise();

          final row = {
            'id': 1,
            'name': 'Chest Day',
            'order': 0,
            'created_at': '2025-07-21T10:00:00Z',
            'exercises': jsonEncode(
              we.map(
                (e) {
                  return {
                    ...e.toMap(),
                    'exercise': 'Push Up',
                  };
                },
              ).toList(),
            )
          };

          when(db.rawQuery(userQuery, [userId])).thenAnswer((_) async => [row]);

          final result = await local.getTemplates(userId, (_) => we.exercise);

          expect(result, hasLength(1));

          final template = result.first;
          expect(template.name, equals('Chest Day'));
          expect(template, hasLength(1));
          expect(template.first.exercise.name, equals('Push Up'));

          verify(db.rawQuery(userQuery, [userId])).called(1);
        },
      );

      test(
        'groups templates by templateId and parses correctly (sample templates)',
        () async {
          final we = wExercise();

          final row = {
            'id': 1,
            'name': 'Full Body',
            'order': 0,
            'created_at': '2025-07-21T10:00:00Z',
            'exercises': jsonEncode(
              we.map(
                (e) {
                  return {
                    ...e.toMap(),
                    'exercise': 'Push Up',
                  };
                },
              ).toList(),
            )
          };

          when(db.rawQuery(sampleQuery, null)).thenAnswer((_) async => [row]);

          final result = await local.getTemplates(null, (_) => exercise());

          expect(result, hasLength(1));
          expect(result.first.name, equals('Full Body'));
          expect(result.first.first.exercise.name, equals('Push Up'));

          verify(db.rawQuery(sampleQuery, null)).called(1);
        },
      );
    },
  );

  group(
    'startTemplate',
    () {
      test(
        'inserts template with provided order and userId',
        () async {
          const userId = 'user-1';
          const order = 5;
          final insertedId = DateTime.timestamp().toIso8601String();

          when(
            txn.insert(
              'templates',
              argThat(
                allOf(
                  containsPair('user_id', userId),
                  containsPair('order_in_parent', order),
                  contains('id'),
                ),
              ),
              conflictAlgorithm: ConflictAlgorithm.replace,
            ),
          ).thenAnswer((_) async => 1);

          final result = await local.startTemplate(order: order, userId: userId);

          expect(result.id.substring(0, 19), insertedId.substring(0, 19));
          expect(result.order, order);
          expect(result.name, isNull);
          expect(result, isEmpty);

          verify(
            txn.insert(
              'templates',
              argThat(
                allOf(
                  containsPair('user_id', userId),
                  containsPair('order_in_parent', order),
                  contains('id'),
                ),
              ),
              conflictAlgorithm: anyNamed('conflictAlgorithm'),
            ),
          ).called(1);
        },
      );

      test(
        'calculates order when not provided (uses max + 1)',
        () async {
          const userId = 'user-2';
          const maxOrder = 2;
          const newOrder = 3;
          const insertedId = 456;

          when(txn.rawQuery('SELECT MAX(order_in_parent) AS max_value FROM templates')).thenAnswer(
            (_) async => [
              {'max': maxOrder}
            ],
          );

          when(
            txn.insert(
              'templates',
              {
                'user_id': userId,
                'order_in_parent': newOrder,
              },
            ),
          ).thenAnswer((_) async => insertedId);
          when(txn.insert(any, any)).thenAnswer((_) async => insertedId);

          final result = await local.startTemplate(userId: userId);

          expect(result.id, insertedId.toString());
          expect(result.order, newOrder);
          expect(result, isEmpty);
          verify(
            txn.insert(
              'templates',
              {
                'user_id': userId,
                'order_in_parent': newOrder,
              },
            ),
          ).called(1);
        },
        skip: 'Bug',
      );

      test(
        'defaults order to 0 if no templates exist',
        () async {
          const userId = 'user-3';
          const insertedId = 789;

          when(
            txn.rawQuery('SELECT MAX(order_in_parent) AS max FROM templates'),
          ).thenAnswer(
            (_) async => [
              {'max': null}
            ],
          );
          when(txn.insert(any, any)).thenAnswer((_) async => insertedId);

          when(
            txn.insert(
              'templates',
              {
                'user_id': userId,
                'order_in_parent': 0,
              },
            ),
          ).thenAnswer((_) async => insertedId);

          final result = await local.startTemplate(userId: userId);

          expect(result.id, insertedId.toString());
          expect(result.order, 0);
          expect(result, isEmpty);
          verify(
            txn.insert(
              'templates',
              {
                'user_id': userId,
                'order_in_parent': 0,
              },
            ),
          ).called(1);
        },
        skip: 'Bug',
      );
    },
  );
}
