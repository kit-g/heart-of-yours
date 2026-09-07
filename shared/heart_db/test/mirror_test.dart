import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The mirror's own side of the count `GET /accounts/summary` answers for the
/// account, and the mark that says this device holds the whole history
/// (heart-of-yours#113).
///
/// What is pinned is the scope of each count. Every row the server would never
/// have seen — a workout still running, a draft with no name, a library
/// exercise, another account's rows — has to stay out, because a mirror that
/// counts too high reads as whole and the backfill never runs.
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

  Future<void> workout(String id, {String uid = user, bool synced = true, bool finished = true}) {
    return db.insert('workouts', {
      'id': id,
      'start': '2026-09-01T10:00:00.000Z',
      'end': ?switch (finished) {
        true => '2026-09-01T11:00:00.000Z',
        false => null,
      },
      'user_id': uid,
      'synced': switch (synced) {
        true => 1,
        false => 0,
      },
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

    test('a workout the server has never seen is not counted', () async {
      await workout('0198d1-workout');
      // in progress, or finished and not yet pushed: either way the account
      // does not have it, so counting it would hide a shortfall of one
      await workout('0198d9-local', synced: false);

      final summary = await local.mirrorSummary(user);

      expect(summary[.workouts].count, 1);
      expect(summary[.workouts].latestId, '0198d1-workout');
    });

    test('an abandoned session counts — the account holds those too', () async {
      await workout('0198d1-workout');
      // no `end`, but synced: the server has it and counts it, so a mirror
      // that did not would be permanently short of a target it cannot reach
      await workout('0198d2-abandoned', finished: false);

      final summary = await local.mirrorSummary(user);

      expect(summary[.workouts].count, 2);
      expect(summary[.workouts].latestId, '0198d2-abandoned');
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

  group('the history backfill mark', () {
    test('is absent until it is written, and per uid', () async {
      expect(await local.isHistoryBackfilled(user), isFalse);

      await local.markHistoryBackfilled(user);

      expect(await local.isHistoryBackfilled(user), isTrue);
      // a second account on the same device does not inherit the claim
      expect(await local.isHistoryBackfilled(other), isFalse);
    });

    test('an erase takes it with the rows', () async {
      await workout('0198d1-workout');
      await local.markHistoryBackfilled(user);

      await local.eraseUser(user);

      // the device holds none of the history now, so the claim that it holds
      // all of it has to go with it
      expect(await local.isHistoryBackfilled(user), isFalse);
    });
  });
}
