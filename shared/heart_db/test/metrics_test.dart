import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_db/src/sql.dart' as sql;
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'mocks.mocks.dart';
import 'utils.dart';

void main() {
  late LocalDatabase local;
  final db = MockDatabase();
  final txn = MockTransaction();
  final batch = MockBatch();

  final ex = exercise(name: 'Push Up');
  const userId = 'user-1';

  final metricRow = {
    'value': 100,
    'when': '2025-07-20T12:00:00Z',
  };

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
    'getRepsHistory',
    () {
      test(
        'getRepsHistory returns parsed metric list',
        () async {
          when(
            db.rawQuery(sql.getRepsHistory, [userId, ex.name, 30]),
          ).thenAnswer((_) async => [metricRow]);

          final result = await local.getRepsHistory(userId, ex);

          expect(result, hasLength(1));
          expect(result.first.$1, 100);
          expect(result.first.$2, DateTime.parse('2025-07-20T12:00:00Z'));
        },
      );

      test(
        'getWeightHistory works with limit',
        () async {
          when(
            db.rawQuery(sql.getWeightHistory, [userId, ex.name, 10]),
          ).thenAnswer((_) async => [metricRow]);

          final result = await local.getWeightHistory(userId, ex, limit: 10);
          expect(result.first.$1, 100);
        },
      );

      test(
        'getDistanceHistory returns empty list when no data',
        () async {
          when(
            db.rawQuery(sql.getDistanceHistory, [userId, ex.name, 30]),
          ).thenAnswer((_) async => []);

          final result = await local.getDistanceHistory(userId, ex);

          expect(result, isEmpty);
        },
      );

      test(
        'getDurationHistory throws on malformed data',
        () async {
          when(
            db.rawQuery(sql.getDurationHistory, [userId, ex.name, 30]),
          ).thenAnswer(
            (_) async => [
              {'when': '2025-07-20T12:00:00Z'}, // missing 'value'
            ],
          );

          expect(
            () => local.getDurationHistory(userId, ex),
            throwsA(isA<ArgumentError>()),
          );
        },
      );
    },
  );
}
