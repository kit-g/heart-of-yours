import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The mirror's side of the export completeness check: what this device holds
/// per collection, in the shape `GET /accounts/summary` answers in.
///
/// What is pinned is the scope of each count. Every row the server would never
/// have seen — a workout still running, a draft with no name, a library
/// exercise, another account's rows — has to stay out, because a mirror that
/// counts too high reads as complete and says nothing.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'user-1';
  const other = 'user-2';

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await db.execute('PRAGMA foreign_keys = ON');
    // the CDN's, nobody's own
    await db.insert('exercises', {
      'id': 'catalog-push-up',
      'name': 'Push Up',
      'category': 'Weighted Body Weight',
      'target': 'Chest',
    });
  });

  tearDown(() => db.close());

  Future<void> workout(String id, {String uid = user, bool finished = true}) {
    return db.insert('workouts', {
      'id': id,
      'start': '2026-09-01T10:00:00.000Z',
      'end': ?switch (finished) {
        true => '2026-09-01T11:00:00.000Z',
        false => null,
      },
      'user_id': uid,
    });
  }

  Future<void> custom(String id, {String uid = user}) {
    return db.insert('exercises', {
      'id': id,
      'name': 'Custom $id',
      'category': 'Weighted Body Weight',
      'target': 'Chest',
      'user_id': uid,
      'own': 1,
    });
  }

  Future<void> template(String id, {String uid = user, String? name = 'Push day'}) {
    return db.insert('templates', {'id': id, 'name': name, 'user_id': uid, 'order_in_parent': 0});
  }

  Future<void> folder(String id, {String uid = user}) {
    return db.insert('template_folders', {'id': id, 'user_id': uid, 'name': 'Push', 'order_index': 0});
  }

  Future<void> goal(String id, {String uid = user, bool archived = false}) {
    return db.insert('goals', {
      'id': id,
      'user_id': uid,
      'metric': 'topSetWeight',
      'stages': '[]',
      'archived': switch (archived) {
        true => 1,
        false => 0,
      },
    });
  }

  group('mirrorSummary', () {
    test('an empty store is zero everywhere, with no heads', () async {
      final summary = await local.mirrorSummary(user);

      expect(summary.total, 0);
      for (final collection in summary.collections.keys) {
        expect(summary[collection].count, 0, reason: '${collection.name} count');
        expect(summary[collection].latestId, isNull, reason: '${collection.name} head');
      }
    });

    test('reports only the collections a mirror can answer for', () async {
      final summary = await local.mirrorSummary(user);

      expect(
        summary.collections.keys,
        // no exercisePreferences: the app spreads those over two tables and
        // keeps no row ids for them. No comments, connections or shares: the
        // device holds none of it, and zero would read as "the server has
        // rows I am missing".
        containsAll(<ExportableCollection>[.customExercises, .templateFolders, .templates, .workouts, .goals]),
      );
      expect(summary.collections.keys, hasLength(5));
      expect(summary.collections.containsKey(ExportableCollection.exercisePreferences), isFalse);
      expect(summary.collections.containsKey(ExportableCollection.workoutImages), isFalse);
    });

    test('counts each collection and names its newest row', () async {
      await custom('0198a1-custom');
      await custom('0198a2-custom');
      await folder('0198b1-folder');
      await template('0198c1-template');
      await workout('0198d1-workout');
      await workout('0198d2-workout');
      await workout('0198d3-workout');
      await goal('0198e1-goal');

      final summary = await local.mirrorSummary(user);

      expect(summary[.customExercises].count, 2);
      expect(summary[.customExercises].latestId, '0198a2-custom');
      expect(summary[.templateFolders].count, 1);
      expect(summary[.templateFolders].latestId, '0198b1-folder');
      expect(summary[.templates].count, 1);
      expect(summary[.workouts].count, 3);
      // uuid v7 renders in an order text sorts the same way, which is the whole
      // reason a head id works as a high-water mark
      expect(summary[.workouts].latestId, '0198d3-workout');
      expect(summary[.goals].count, 1);
      expect(summary.total, 8);
    });

    test('a workout still running is not counted', () async {
      await workout('0198d1-workout');
      await workout('0198d9-running', finished: false);

      final summary = await local.mirrorSummary(user);

      expect(summary[.workouts].count, 1);
      // the head is the newest *finished* row, not the newest row
      expect(summary[.workouts].latestId, '0198d1-workout');
    });

    test('a draft with no name is not counted', () async {
      await template('0198c1-template');
      await template('0198c9-draft', name: null);

      final summary = await local.mirrorSummary(user);

      expect(summary[.templates].count, 1);
      expect(summary[.templates].latestId, '0198c1-template');
    });

    test('a library exercise is not one of the account\'s own', () async {
      await custom('0198a1-custom');

      final summary = await local.mirrorSummary(user);

      // `catalog-push-up` is seeded for every test and belongs to nobody
      expect(summary[.customExercises].count, 1);
      expect(summary[.customExercises].latestId, '0198a1-custom');
    });

    test('another account on the same device is not counted', () async {
      await custom('0198a1-custom');
      await custom('0198a9-theirs', uid: other);
      await workout('0198d9-theirs', uid: other);
      await goal('0198e9-theirs', uid: other);

      final summary = await local.mirrorSummary(user);

      expect(summary[.customExercises].count, 1);
      expect(summary[.workouts].count, 0);
      expect(summary[.goals].count, 0);
    });

    test('an archived goal counts — the account still holds it', () async {
      await goal('0198e1-live');
      await goal('0198e2-archived', archived: true);

      final summary = await local.mirrorSummary(user);

      expect(summary[.goals].count, 2);
      expect(summary[.goals].latestId, '0198e2-archived');
    });
  });
}
