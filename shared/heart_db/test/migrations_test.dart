import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Migration tests run against a real on-disk SQLite database, opened through
/// [LocalDatabase.init] so the exact production plumbing (onCreate/onUpgrade,
/// the migration transaction, `PRAGMA foreign_keys`) is exercised.
///
/// [LocalDatabase.init] resolves its path via the active [databaseFactory], so
/// each test points the ffi factory at a fresh temp directory. The raw handle
/// used for seeding and assertions is the same single-instance connection that
/// `init` opened — closing it lets the next `init` re-open the file and run
/// the upgrade path.
void main() {
  late Directory dir;
  late String path;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('heart_db_migrations_');
    await databaseFactory.setDatabasesPath(dir.path);
    path = p.join(dir.path, 'heart.db');
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  /// Same single-instance connection as the one [LocalDatabase.init] opened.
  Future<Database> raw() => databaseFactory.openDatabase(path);

  Future<int> userVersion(Database db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    return rows.first.values.first as int;
  }

  Future<Set<String>> tables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    return rows.map((row) => row['name'] as String).toSet();
  }

  /// column name -> declared type, from `PRAGMA table_info`.
  Future<Map<String, String>> columns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return {
      for (final row in rows) row['name'] as String: row['type'] as String,
    };
  }

  Future<Set<String>> indexesOn(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ? AND name NOT LIKE 'sqlite_%'",
      [table],
    );
    return rows.map((row) => row['name'] as String).toSet();
  }

  /// Representative data valid under the v1 schema, including the shapes the
  /// destructive v3/v4 steps have to carry across: template exercises (table
  /// rebuild), pre-`synced` workouts (backfill), and duplicate chart
  /// preferences (dedupe).
  Future<void> seedV1(Database db) async {
    await db.insert('exercises', {
      'name': 'Bench Press',
      'category': 'Barbell',
      'target': 'Chest',
    });
    await db.insert('workouts', {
      'id': 'w1',
      'start': '2025-01-01T10:00:00+00:00',
      'user_id': 'u1',
      'name': 'Push',
    });
    await db.insert('workout_exercises', {
      'workout_id': 'w1',
      'exercise_id': 'Bench Press',
      'id': 'we1',
      'exercise_order': 0,
    });
    await db.insert('sets', {
      'exercise_id': 'we1',
      'id': 's1',
      'completed': 1,
      'weight': 60.0,
      'reps': 8,
    });
    await db.insert('templates', {
      'id': 'tpl-1',
      'name': 'Push day',
      'user_id': 'u1',
      'order_in_parent': 0,
    });
    await db.insert('template_exercises', {
      'id': 'te1',
      'template_id': 'tpl-1',
      'exercise_id': 'Bench Press',
      'description': 'Bench Press: 3x8',
    });
    await db.insert('exercise_details', {
      'exercise_name': 'Bench Press',
      'user_id': 'u1',
      'rest_timer': 90,
    });

    // charts ids autoincrement 1..7:
    // 1,2,3 - duplicates of (u1, exercise, Bench Press)
    // 4     - (u1, exercise, Squat)
    // 5     - (u2, exercise, Bench Press), same chart but another user
    // 6,7   - duplicates of (u1, summary, NULL data)
    for (var i = 0; i < 3; i++) {
      await db.insert('charts', {'user_id': 'u1', 'type': 'exercise', 'data': 'Bench Press'});
    }
    await db.insert('charts', {'user_id': 'u1', 'type': 'exercise', 'data': 'Squat'});
    await db.insert('charts', {'user_id': 'u2', 'type': 'exercise', 'data': 'Bench Press'});
    for (var i = 0; i < 2; i++) {
      await db.insert('charts', {'user_id': 'u1', 'type': 'summary'});
    }
  }

  group(
    'fresh install',
    () {
      test(
        'default init lands on the latest schema version with all tables',
        () async {
          await LocalDatabase.init();
          final db = await raw();

          expect(await userVersion(db), 8);
          expect(
            await tables(db),
            {
              'exercises',
              'syncs',
              'workouts',
              'workout_exercises',
              'sets',
              'templates',
              'template_exercises',
              'template_folders',
              'exercise_details',
              'charts',
              'goals',
            },
          );

          await db.close();
        },
      );

      test(
        'fresh schema carries every migrated column and index',
        () async {
          await LocalDatabase.init();
          final db = await raw();

          // v2
          expect(await columns(db, 'exercise_details'), containsPair('unit_system', 'TEXT'));
          expect(await columns(db, 'exercises'), containsPair('id', 'TEXT'));
          // v3: the rebuild fixed the affinity of the FK column
          expect(await columns(db, 'template_exercises'), containsPair('template_id', 'TEXT'));
          expect(await columns(db, 'workouts'), containsPair('synced', 'INTEGER'));
          // v4
          expect(await columns(db, 'charts'), containsPair('sort_order', 'INTEGER'));
          expect(await indexesOn(db, 'charts'), containsAll({'user_idx', 'charts_unique_idx'}));
          // v5
          expect(await columns(db, 'exercises'), contains('movement'));

          expect(await indexesOn(db, 'template_exercises'), {'template_idx'});
          // `exercise_idx` is claimed three times in 0001.dart (workout_exercises,
          // sets, template_exercises); index names are database-global, so only
          // the first CREATE wins and the other two are skipped by IF NOT EXISTS.
          // v3 recovered template_exercises; v6 gives sets its own index.
          expect(await indexesOn(db, 'workout_exercises'), {'exercise_idx', 'workout_idx'});
          expect(await indexesOn(db, 'sets'), {'sets_exercise_idx'});

          await db.close();
        },
      );
    },
  );

  group(
    'upgrade from v1',
    () {
      test(
        'v2 adds unit_system and exercises.id, existing rows unaffected',
        () async {
          await LocalDatabase.init(version: 1);
          var db = await raw();
          await seedV1(db);
          await db.close();

          await LocalDatabase.init(version: 2);
          db = await raw();

          expect(await userVersion(db), 2);

          final [details] = await db.query('exercise_details');
          expect(details['unit_system'], isNull);
          expect(details['rest_timer'], 90);

          final [bench] = await db.query('exercises');
          expect(bench['id'], isNull);
          expect(bench['name'], 'Bench Press');

          // the new column's CHECK constraint is live
          expect(
            () => db.insert('exercise_details', {
              'exercise_name': 'Bench Press',
              'user_id': 'u2',
              'unit_system': 'bananas',
            }),
            throwsA(isA<DatabaseException>()),
          );

          await db.close();
        },
      );

      test(
        'v3 rebuild keeps template exercises intact and backfills synced',
        () async {
          await LocalDatabase.init(version: 1);
          var db = await raw();
          await seedV1(db);
          await db.close();

          await LocalDatabase.init(version: 3);
          db = await raw();

          // the rebuilt table has the corrected affinity and the same data
          expect(await columns(db, 'template_exercises'), containsPair('template_id', 'TEXT'));
          expect(await indexesOn(db, 'template_exercises'), {'template_idx'});
          expect(
            await db.query('template_exercises'),
            [
              {
                'id': 'te1',
                'template_id': 'tpl-1',
                'exercise_id': 'Bench Press',
                'description': 'Bench Press: 3x8',
              },
            ],
          );

          // pre-existing workouts are assumed on the server; new ones are not
          final [w1] = await db.query('workouts', where: "id = 'w1'");
          expect(w1['synced'], 1);
          await db.insert('workouts', {
            'id': 'w2',
            'start': '2025-01-02T10:00:00+00:00',
            'user_id': 'u1',
          });
          final [w2] = await db.query('workouts', where: "id = 'w2'");
          expect(w2['synced'], 0);

          // the rebuilt table still cascades from templates
          await db.delete('templates', where: "id = 'tpl-1'");
          expect(await db.query('template_exercises'), isEmpty);

          await db.close();
        },
      );

      test(
        'v4 dedupes chart preferences, keeps distinct rows and seeds sort_order',
        () async {
          await LocalDatabase.init(version: 1);
          var db = await raw();
          await seedV1(db);
          await db.close();

          await LocalDatabase.init(version: 4);
          db = await raw();

          // earliest row of each (user_id, type, data) group survives;
          // NULL data groups together, so the summary duplicates collapse too
          final charts = await db.query('charts', orderBy: 'id');
          expect(
            charts,
            [
              {'id': 1, 'user_id': 'u1', 'type': 'exercise', 'data': 'Bench Press', 'sort_order': 1},
              {'id': 4, 'user_id': 'u1', 'type': 'exercise', 'data': 'Squat', 'sort_order': 4},
              {'id': 5, 'user_id': 'u2', 'type': 'exercise', 'data': 'Bench Press', 'sort_order': 5},
              {'id': 6, 'user_id': 'u1', 'type': 'summary', 'data': null, 'sort_order': 6},
            ],
          );

          // the unique index now rejects a straight re-insert
          expect(
            () => db.insert('charts', {'user_id': 'u2', 'type': 'exercise', 'data': 'Bench Press'}),
            throwsA(isA<DatabaseException>()),
          );

          await db.close();
        },
      );

      test(
        'v1 to v5 in one jump carries all seeded data to the final schema',
        () async {
          await LocalDatabase.init(version: 1);
          var db = await raw();
          await seedV1(db);
          await db.close();

          await LocalDatabase.init(version: 5);
          db = await raw();

          expect(await userVersion(db), 5);

          final [bench] = await db.query('exercises');
          expect(bench['name'], 'Bench Press');
          expect(bench['movement'], isNull);

          final [s1] = await db.query('sets');
          expect(s1['weight'], 60.0);
          expect(s1['reps'], 8);

          final [te] = await db.query('template_exercises');
          expect(te['template_id'], 'tpl-1');

          final [w1] = await db.query('workouts');
          expect(w1['synced'], 1);

          expect(await db.query('charts'), hasLength(4));

          await db.close();
        },
      );

      test(
        'upgrading one version at a time reaches the same final state',
        () async {
          await LocalDatabase.init(version: 1);
          var db = await raw();
          await seedV1(db);
          await db.close();

          for (final version in [2, 3, 4, 5]) {
            await LocalDatabase.init(version: version);
            db = await raw();

            expect(await userVersion(db), version);

            switch (version) {
              case 2:
                expect(await columns(db, 'exercise_details'), contains('unit_system'));
              case 3:
                final [te] = await db.query('template_exercises');
                expect(te['id'], 'te1');
                final [w1] = await db.query('workouts');
                expect(w1['synced'], 1);
              case 4:
                expect(await db.query('charts'), hasLength(4));
              case 5:
                expect(await columns(db, 'exercises'), contains('movement'));
            }

            await db.close();
          }
        },
      );
    },
  );

  group(
    'idempotence',
    () {
      test(
        'reopening at the same version runs no migrations and keeps data',
        () async {
          await LocalDatabase.init();
          var db = await raw();
          await db.insert('exercises', {
            'name': 'Squat',
            'category': 'Barbell',
            'target': 'Legs',
          });
          await db.insert('charts', {
            'user_id': 'u1',
            'type': 'exercise',
            'data': 'Squat',
            'sort_order': 0,
          });
          await db.close();

          await LocalDatabase.init();
          db = await raw();

          expect(await userVersion(db), 8);
          expect(await db.query('exercises'), hasLength(1));
          // a second dedupe/backfill pass would have rewritten sort_order to id
          final [chart] = await db.query('charts');
          expect(chart['sort_order'], 0);

          await db.close();
        },
      );
    },
  );
}
