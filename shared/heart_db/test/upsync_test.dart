import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The store's half of the anonymous-to-account upsync (heart-of-yours#96),
/// against a real in-memory SQLite.
///
/// What is pinned is relational: a rekey moves every uid-keyed row and lets
/// the anonymous copy win a natural-key collision; a merge moves every
/// reference before the old row goes, so no cascade takes the workout with it;
/// the ledger and the debt live and die together.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const anonymous = 'anon-1';
  const account = 'acct-1';

  Future<int> count(String table, {String? where, List<Object?>? args}) async {
    final rows = await db.query(table, columns: ['count(*) AS n'], where: where, whereArgs: args);
    return rows.single['n'] as int;
  }

  /// One of everything a session can hold, under [uid]. Ids carry the uid so
  /// two sessions' rows never collide on a primary key — except where a test
  /// wants them to.
  Future<void> seed(String uid, {String unit = 'metric'}) async {
    await db.insert('exercises', {
      'id': '$uid-own',
      'name': '$uid own exercise',
      'category': 'Weighted Body Weight',
      'target': 'Chest',
      'user_id': uid,
      'own': 1,
    });
    await db.insert('exercise_details', {
      'exercise_id': 'catalog-push-up',
      'user_id': uid,
      'unit_system': unit,
    });
    await db.insert('workouts', {
      'id': '$uid-workout',
      'start': '2026-09-01T10:00:00.000Z',
      'end': '2026-09-01T11:00:00.000Z',
      'user_id': uid,
      'synced': 0,
    });
    await db.insert('workout_exercises', {
      'id': '$uid-workout-exercise',
      'workout_id': '$uid-workout',
      'exercise_id': '$uid-own',
      'exercise_order': 0,
    });
    await db.insert('sets', {
      'id': '$uid-set',
      'exercise_id': '$uid-workout-exercise',
      'completed': 1,
      'weight': 50,
      'reps': 10,
    });
    await db.insert('template_folders', {'id': '$uid-folder', 'user_id': uid, 'name': 'Push', 'order_index': 0});
    await db.insert('templates', {
      'id': '$uid-template',
      'name': 'Push day',
      'user_id': uid,
      'order_in_parent': 0,
      'folder_id': '$uid-folder',
    });
    await db.insert('template_exercises', {
      'id': '$uid-template-exercise',
      'template_id': '$uid-template',
      'exercise_id': '$uid-own',
    });
    await db.insert('charts', {
      'user_id': uid,
      'type': 'exercise',
      'data': '{"exerciseName":"$uid-own"}',
      'sort_order': 0,
    });
    await db.insert('goals', {
      'id': '$uid-goal',
      'user_id': uid,
      'metric': 'topSetWeight',
      'exercise_id': '$uid-own',
      'stages': '[]',
    });
    await db.insert('health_samples', {
      'id': '$uid-sample',
      'user_id': uid,
      'metric': 'steps',
      'value': 1000,
      'unit': 'count',
      'start': '2026-09-01T00:00:00.000Z',
      'end': '2026-09-01T01:00:00.000Z',
    });
    await db.insert('syncs', {
      'table_name': 'health_backfill:$uid:steps',
      'synced_at': '2026-09-0${uid == anonymous ? 1 : 2}T00:00:00.000Z',
    });
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.insert('exercises', {
      'id': 'catalog-push-up',
      'name': 'Push Up',
      'category': 'Weighted Body Weight',
      'target': 'Chest',
    });
  });

  tearDown(() => db.close());

  group('rekeyUser', () {
    test('moves every uid-keyed row onto the account and leaves nothing behind', () async {
      await seed(anonymous);

      await local.rekeyUser(anonymous, account);

      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final swept = <String>[];
      for (final table in tables.map((row) => row['name'] as String)) {
        final columns = await db.rawQuery('PRAGMA table_info($table)');
        if (!columns.any((column) => column['name'] == 'user_id')) continue;
        swept.add(table);
        expect(
          await count(table, where: 'user_id = ?', args: [anonymous]),
          0,
          reason: '$table kept the old uid',
        );
      }
      expect(
        swept,
        containsAll(['workouts', 'exercises', 'exercise_details', 'templates', 'template_folders', 'charts', 'goals']),
      );
      // the children ride along with their parents, untouched
      expect(await count('sets', where: 'exercise_id = ?', args: ['$anonymous-workout-exercise']), 1);
      expect(await count('template_exercises', where: 'template_id = ?', args: ['$anonymous-template']), 1);
      // the health store is this device's under either uid, markers included
      expect(await count('health_samples', where: 'user_id = ?', args: [account]), 1);
      expect(await count('syncs', where: 'table_name = ?', args: ['health_backfill:$account:steps']), 1);
      expect(await count('syncs', where: 'table_name LIKE ?', args: ['health_backfill:$anonymous:%']), 0);
    });

    test('the anonymous row wins a natural-key collision with an earlier mirror of the account', () async {
      await seed(account, unit: 'imperial');
      await seed(anonymous, unit: 'metric');

      await local.rekeyUser(anonymous, account);

      // one preference per (exercise, uid), and it is the device's latest intent
      final [preference] = await db.query('exercise_details', where: 'exercise_id = ?', whereArgs: ['catalog-push-up']);
      expect(preference['user_id'], account);
      expect(preference['unit_system'], 'metric');
      // the two uids' health markers collide on the key; the anonymous one survives
      final [marker] = await db.query('syncs', where: 'table_name = ?', whereArgs: ['health_backfill:$account:steps']);
      expect(marker['synced_at'], '2026-09-01T00:00:00.000Z');
      // rows with their own ids do not collide and are simply both there
      expect(await count('workouts', where: 'user_id = ?', args: [account]), 2);
      expect(await count('goals', where: 'user_id = ?', args: [account]), 2);
    });

    test('leaves another uid and the catalog alone', () async {
      await seed(anonymous);
      await seed('bystander');

      await local.rekeyUser(anonymous, account);

      expect(await count('workouts', where: 'user_id = ?', args: ['bystander']), 1);
      expect(await count('exercises', where: 'user_id IS NULL'), 1);
    });
  });

  group('the debt and the ledger', () {
    test('a replay is owed once recorded, and not before', () async {
      expect(await local.isUpsyncOwed(account), isFalse);

      await local.oweUpsync(account);
      await local.oweUpsync(account);

      expect(await local.isUpsyncOwed(account), isTrue);
      expect(await local.isUpsyncOwed(anonymous), isFalse);
    });

    test('records each confirmed step once, latest answer wins', () async {
      await local.recordUpsync(account, (resource: 'workout', id: 'w1', outcome: 'created'));
      await local.recordUpsync(account, (resource: 'workout', id: 'w2', outcome: 'existing'));
      await local.recordUpsync(account, (resource: 'workout', id: 'w1', outcome: 'existing'));
      await local.recordUpsync(anonymous, (resource: 'workout', id: 'w1', outcome: 'created'));

      final ledger = await local.upsyncLedger(account);
      expect(ledger, hasLength(2));
      expect(ledger, contains((resource: 'workout', id: 'w1', outcome: 'existing')));
      expect(ledger, contains((resource: 'workout', id: 'w2', outcome: 'existing')));
    });

    test('settling clears the debt and the ledger together, for that uid only', () async {
      await local.oweUpsync(account);
      await local.oweUpsync(anonymous);
      await local.recordUpsync(account, (resource: 'goal', id: 'g1', outcome: 'created'));
      await local.recordUpsync(anonymous, (resource: 'goal', id: 'g1', outcome: 'created'));

      await local.settleUpsync(account);

      expect(await local.isUpsyncOwed(account), isFalse);
      expect(await local.upsyncLedger(account), isEmpty);
      expect(await local.isUpsyncOwed(anonymous), isTrue);
      expect(await local.upsyncLedger(anonymous), hasLength(1));
    });

    test('the ledger follows a rekey and goes with an erase', () async {
      await local.oweUpsync(anonymous);
      await local.recordUpsync(anonymous, (resource: 'goal', id: 'g1', outcome: 'created'));

      await local.rekeyUser(anonymous, account);
      expect(await local.upsyncLedger(account), hasLength(1));

      await local.oweUpsync(account);
      await local.eraseUser(account);
      expect(await local.upsyncLedger(account), isEmpty);
      expect(await local.isUpsyncOwed(account), isFalse);
    });
  });

  group('mergeExercise', () {
    setUp(() async {
      await seed(account);
      // the server's copy — the custom the account already had by that name —
      // is stored before the merge, as the replay does
      await db.insert('exercises', {
        'id': 'server-own',
        'name': '$account own exercise',
        'category': 'Weighted Body Weight',
        'target': 'Chest',
        'user_id': account,
        'own': 1,
      });
    });

    test('moves every reference onto the surviving id and drops the merged row', () async {
      await db.insert('exercise_details', {
        'exercise_id': '$account-own',
        'user_id': account,
        'unit_system': 'imperial',
      });

      await local.mergeExercise(account, from: '$account-own', to: 'server-own');

      expect(await count('exercises', where: 'id = ?', args: ['$account-own']), 0);
      final [workoutExercise] = await db.query(
        'workout_exercises',
        where: 'workout_id = ?',
        whereArgs: ['$account-workout'],
      );
      expect(workoutExercise['exercise_id'], 'server-own');
      final [templateExercise] = await db.query(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: ['$account-template'],
      );
      expect(templateExercise['exercise_id'], 'server-own');
      final [goal] = await db.query('goals', where: 'user_id = ?', whereArgs: [account]);
      expect(goal['exercise_id'], 'server-own');
      final [chart] = await db.query('charts', where: 'user_id = ?', whereArgs: [account]);
      expect(chart['data'], '{"exerciseName":"server-own"}');
      final [preference] = await db.query('exercise_details', where: 'exercise_id = ?', whereArgs: ['server-own']);
      expect(preference['unit_system'], 'imperial');
    });

    test('the workout keeps its sets — the references moved before the row went', () async {
      await local.mergeExercise(account, from: '$account-own', to: 'server-own');

      expect(await count('sets', where: 'exercise_id = ?', args: ['$account-workout-exercise']), 1);
      expect(await count('workout_exercises', where: 'workout_id = ?', args: ['$account-workout']), 1);
    });

    test('is scoped to the uid: another user\'s reference to the same id is not rewritten', () async {
      await seed('bystander');
      // a goal's exercise reference carries no foreign key, so it survives the
      // merged row going and shows whether the rewrite stayed in its lane
      await db.update('goals', {'exercise_id': '$account-own'}, where: 'id = ?', whereArgs: ['bystander-goal']);

      await local.mergeExercise(account, from: '$account-own', to: 'server-own');

      final [theirs] = await db.query('goals', where: 'id = ?', whereArgs: ['bystander-goal']);
      expect(theirs['exercise_id'], '$account-own');
    });

    test('a preference on the merged exercise wins over one the account already had', () async {
      await db.insert('exercise_details', {
        'exercise_id': '$account-own',
        'user_id': account,
        'unit_system': 'imperial',
      });
      await db.insert('exercise_details', {'exercise_id': 'server-own', 'user_id': account, 'unit_system': 'metric'});

      await local.mergeExercise(account, from: '$account-own', to: 'server-own');

      final rows = await db.query(
        'exercise_details',
        where: 'exercise_id = ? AND user_id = ?',
        whereArgs: ['server-own', account],
      );
      expect(rows.single['unit_system'], 'imperial');
    });
  });

  group('mergeFolder', () {
    test('refiles the templates and drops the merged folder', () async {
      await seed(account);
      await db.insert('template_folders', {
        'id': 'server-folder',
        'user_id': account,
        'name': 'push',
        'order_index': 3,
      });

      await local.mergeFolder(account, from: '$account-folder', to: 'server-folder');

      final [template] = await db.query('templates', where: 'id = ?', whereArgs: ['$account-template']);
      expect(template['folder_id'], 'server-folder');
      expect(await count('template_folders', where: 'id = ?', args: ['$account-folder']), 0);
      expect(await count('template_folders', where: 'id = ?', args: ['server-folder']), 1);
    });
  });

  test('a new template is minted under a platform id the server will accept', () async {
    final template = await local.startTemplate(userId: account);

    expect(isUuidV7(template.id), isTrue);
    expect(template.createdAt, isNotNull);
    final [row] = await db.query('templates', where: 'user_id = ?', whereArgs: [account]);
    expect(row['id'], template.id);
  });
}
