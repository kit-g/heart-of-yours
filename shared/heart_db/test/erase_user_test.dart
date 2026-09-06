import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// "Erase my data" against a real in-memory SQLite carrying the full schema.
///
/// What is pinned is the *shape* of the wipe, which no mock can hold: every
/// table keyed by a uid loses that uid's rows and nobody else's, the child
/// rows that hang off them (sets, workout and template exercises) go with
/// them, and the shared catalog stays. The sweep over `sqlite_master` is the
/// regression guard — a table that gains a `user_id` column without joining
/// [LocalDatabase.eraseUser] fails here instead of surviving an erase.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const erased = 'uid-erased';
  const kept = 'uid-kept';

  /// One of everything a session can hold, under [uid]. Ids are prefixed so
  /// two sessions' rows never collide on a primary key.
  Future<void> seed(String uid) async {
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
      'rest_timer': 90,
      'unit_system': 'imperial',
    });
    await db.insert('workouts', {
      'id': '$uid-workout',
      'start': '2026-09-01T10:00:00.000Z',
      'end': '2026-09-01T11:00:00.000Z',
      'user_id': uid,
      'name': 'Morning',
    });
    await db.insert('workout_exercises', {
      'id': '$uid-workout-exercise',
      'workout_id': '$uid-workout',
      'exercise_id': 'catalog-push-up',
      'exercise_order': 0,
    });
    await db.insert('sets', {
      'id': '$uid-set',
      'exercise_id': '$uid-workout-exercise',
      'completed': 1,
      'weight': 50,
      'reps': 10,
    });
    await db.insert('template_folders', {
      'id': '$uid-folder',
      'user_id': uid,
      'name': 'Push',
      'order_index': 0,
    });
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
      'data': '{"exerciseName":"catalog-push-up"}',
      'sort_order': 0,
    });
    await db.insert('goals', {
      'id': '$uid-goal',
      'user_id': uid,
      'metric': 'topSetWeight',
      'exercise_id': 'catalog-push-up',
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
      'synced_at': '2026-09-01T00:00:00.000Z',
    });
  }

  Future<int> count(String table, {String? where, List<Object?>? args}) async {
    final rows = await db.query(table, columns: ['count(*) AS n'], where: where, whereArgs: args);
    return rows.single['n'] as int;
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);

    // the shared catalog and a sample template: no uid, so not anyone's to erase
    await db.insert('exercises', {
      'id': 'catalog-push-up',
      'name': 'Push Up',
      'category': 'Weighted Body Weight',
      'target': 'Chest',
    });
    await db.insert('syncs', {'table_name': 'exercises', 'locale': 'en', 'version': '1', 'etag': '"e1"'});
    await db.insert('templates', {'id': 'sample-template', 'name': 'Sample', 'order_in_parent': 0});
    await db.insert('template_exercises', {
      'id': 'sample-template-exercise',
      'template_id': 'sample-template',
      'exercise_id': 'catalog-push-up',
    });

    await seed(erased);
    await seed(kept);
  });

  tearDown(() => db.close());

  test('no row under the erased uid remains in any table that carries one', () async {
    await local.eraseUser(erased);

    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final swept = <String>[];
    for (final table in tables.map((row) => row['name'] as String)) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      if (!columns.any((column) => column['name'] == 'user_id')) continue;
      swept.add(table);
      expect(
        await count(table, where: 'user_id = ?', args: [erased]),
        0,
        reason: '$table still holds rows for the erased uid',
      );
    }
    // the sweep only means something if it saw the tables it is meant to
    expect(
      swept,
      containsAll([
        'workouts',
        'exercises',
        'exercise_details',
        'templates',
        'template_folders',
        'charts',
        'goals',
        'health_samples',
      ]),
    );
  });

  test('takes the child rows with it, without leaning on foreign-key cascades', () async {
    // the test connection never turned the pragma on, so an orphan would survive
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 0);

    await local.eraseUser(erased);

    expect(await count('sets', where: 'exercise_id = ?', args: ['$erased-workout-exercise']), 0);
    expect(await count('workout_exercises', where: 'workout_id = ?', args: ['$erased-workout']), 0);
    expect(await count('template_exercises', where: 'template_id = ?', args: ['$erased-template']), 0);
    expect(await count('syncs', where: 'table_name LIKE ?', args: ['health_backfill:$erased:%']), 0);
  });

  test('leaves every other uid, the catalog and the sample templates alone', () async {
    await local.eraseUser(erased);

    for (final table in [
      'workouts',
      'exercises',
      'exercise_details',
      'templates',
      'template_folders',
      'charts',
      'goals',
      'health_samples',
    ]) {
      expect(
        await count(table, where: 'user_id = ?', args: [kept]),
        1,
        reason: '$table lost the other uid\'s row',
      );
    }
    expect(await count('sets', where: 'exercise_id = ?', args: ['$kept-workout-exercise']), 1);
    expect(await count('workout_exercises', where: 'workout_id = ?', args: ['$kept-workout']), 1);
    expect(await count('template_exercises', where: 'template_id = ?', args: ['$kept-template']), 1);
    expect(await count('syncs', where: 'table_name LIKE ?', args: ['health_backfill:$kept:%']), 1);

    expect(await count('exercises', where: 'user_id IS NULL'), 1, reason: 'the catalog is nobody\'s to erase');
    expect(await count('templates', where: 'user_id IS NULL'), 1, reason: 'sample templates are shared');
    expect(await count('template_exercises', where: 'template_id = ?', args: ['sample-template']), 1);
    expect(await local.getCatalogStamp(), isNotNull, reason: 'the catalog stamp is not a uid\'s');
  });

  test('is a no-op for a uid the store has never seen', () async {
    await local.eraseUser('uid-unknown');

    expect(await count('workouts'), 2);
    expect(await count('sets'), 2);
    expect(await count('health_samples'), 2);
  });
}
