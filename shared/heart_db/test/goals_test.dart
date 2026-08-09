import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Against a real in-memory SQLite, not a mock.
///
/// Nearly everything here is a shape the type system cannot hold: the stage
/// ladder is a JSON blob, `archived`/`synced` are integers, and the sync
/// bookkeeping is expressed as which rows a statement is allowed to touch.
/// Stubbing the database would only assert that we pass the string we pass.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  const other = 'user-2';

  /// Goals belong to whoever owns them, and the local mirror only ever holds
  /// the signed-in user's — so reading is always asking for your own.
  Future<Iterable<Goal>> goalsOf(String id) {
    return local.getTargetUserGoals(requesterId: id, targetUserId: id);
  }

  Goal goal({
    String? id,
    GoalMetric metric = GoalMetric.topSetWeight,
    String? exerciseId = 'exercise-1',
    GoalCadence? cadence,
    List<GoalStage>? stages,
    bool archived = false,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id,
      metric: metric,
      exerciseId: exerciseId,
      cadence: cadence,
      stages: stages ?? [GoalStage(target: 100)],
      archived: archived,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    );
  }

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // The real DDL, so a change to the migration breaks this test rather than
    // sailing past a hand-written copy of the schema.
    await db.execute(goals);
    await db.execute(goalsIndex);
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  group('createGoal', () {
    test('mints an id for the goal and for every stage', () async {
      final saved = await local.createGoal(
        goal(stages: [GoalStage(target: 100), GoalStage(target: 140)]),
        userId,
      );

      // a goal written offline has to be addressable before the server sees it
      expect(saved.id, isNotNull);
      expect(saved.stages.map((stage) => stage.id), everyElement(isNotNull));
      expect(saved.stages.first.id, isNot(saved.stages.last.id));
    });

    test('keeps ids it was given, so a pushed ladder stays addressable', () async {
      final saved = await local.createGoal(
        goal(
          id: 'goal-1',
          stages: [GoalStage(id: 'stage-1', target: 100)],
        ),
        userId,
      );

      expect(saved.id, 'goal-1');
      expect(saved.stages.single.id, 'stage-1');
    });

    test('round-trips the whole ladder through the JSON column', () async {
      await local.createGoal(
        goal(
          id: 'goal-1',
          cadence: null,
          stages: [
            GoalStage(id: 's1', target: 100, dueOn: DateTime.utc(2026, 12, 25, 18, 30)),
            GoalStage(id: 's2', target: 140, achievedAt: DateTime.utc(2026, 6, 1)),
          ],
        ),
        userId,
      );

      final read = (await goalsOf(userId)).single;

      expect(read.stages, hasLength(2));
      expect(read.stages.first.target, 100);
      expect(read.stages.first.isAchieved, isFalse);
      expect(read.currentStage?.id, 's1');

      // A deadline is a calendar date, not an instant: the time of day is
      // dropped and it reads back local, so Christmas stays Christmas wherever
      // the user is standing. An achievement *is* an instant, and stays UTC.
      expect(read.stages.first.dueOn, DateTime(2026, 12, 25));
      expect(read.stages.first.dueOn?.isUtc, isFalse);
      expect(read.stages.last.achievedAt, DateTime.utc(2026, 6, 1));
      expect(read.stages.last.achievedAt?.isUtc, isTrue);
    });

    test('round-trips a cadence goal and a whole-workout one', () async {
      await local.createGoal(
        goal(id: 'goal-1', metric: .workouts, exerciseId: null, cadence: .week),
        userId,
      );

      final read = (await goalsOf(userId)).single;

      expect(read.metric, GoalMetric.workouts);
      expect(read.exerciseId, isNull);
      expect(read.cadence, GoalCadence.week);
    });

    test('a new goal is not yet synced', () async {
      await local.createGoal(goal(id: 'goal-1'), userId);

      expect((await local.unsyncedGoals(userId)).map((each) => each.id), ['goal-1']);
    });
  });

  group('getTargetUserGoals', () {
    test('hides archived goals', () async {
      await local.createGoal(goal(id: 'live'), userId);
      await local.createGoal(goal(id: 'gone', archived: true), userId);

      expect((await goalsOf(userId)).map((each) => each.id), ['live']);
    });

    test('reads archived back as a real bool, not a SQLite 1', () async {
      // `Goal.fromRow` accepts both 1 and true; this is the tripwire for that
      await local.createGoal(goal(id: 'gone', archived: true), userId);

      final rows = await db.query('goals', where: 'id = ?', whereArgs: ['gone']);
      expect(rows.single['archived'], 1);
      expect(Goal.fromRow(rows.single).archived, isTrue);
    });

    test('is oldest first', () async {
      await local.createGoal(goal(id: 'second', createdAt: DateTime.utc(2026, 2, 1)), userId);
      await local.createGoal(goal(id: 'first', createdAt: DateTime.utc(2026, 1, 1)), userId);

      expect((await goalsOf(userId)).map((each) => each.id), ['first', 'second']);
    });

    test('is scoped to one user', () async {
      await local.createGoal(goal(id: 'mine'), userId);
      await local.createGoal(goal(id: 'theirs'), other);

      expect((await goalsOf(userId)).map((each) => each.id), ['mine']);
    });
  });

  group('markStageAchieved', () {
    test('stamps the addressed stage and leaves the rest of the ladder alone', () async {
      await local.createGoal(
        goal(
          id: 'goal-1',
          stages: [
            GoalStage(id: 's1', target: 100),
            GoalStage(id: 's2', target: 140),
          ],
        ),
        userId,
      );

      final at = DateTime.utc(2026, 12, 25);
      final updated = await local.markStageAchieved('goal-1', 's2', userId, at);

      expect(updated.stages.first.isAchieved, isFalse);
      expect(updated.stages.last.achievedAt, at);
      // and it persisted, rather than only being returned
      expect((await goalsOf(userId)).single.stages.last.achievedAt, at);
    });

    test('is idempotent — re-stamping overwrites rather than failing', () async {
      await local.createGoal(
        goal(
          id: 'goal-1',
          stages: [GoalStage(id: 's1', target: 100)],
        ),
        userId,
      );

      await local.markStageAchieved('goal-1', 's1', userId, DateTime.utc(2026, 1, 1));
      final second = await local.markStageAchieved('goal-1', 's1', userId, DateTime.utc(2026, 2, 2));

      expect(second.stages.single.achievedAt, DateTime.utc(2026, 2, 2));
    });

    test('rejects a stage id that is not on this goal', () async {
      await local.createGoal(
        goal(
          id: 'goal-1',
          stages: [GoalStage(id: 's1', target: 100)],
        ),
        userId,
      );

      expect(
        () => local.markStageAchieved('goal-1', 'nope', userId, DateTime.utc(2026)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a goal that belongs to somebody else', () async {
      await local.createGoal(
        goal(
          id: 'goal-1',
          stages: [GoalStage(id: 's1', target: 100)],
        ),
        userId,
      );

      expect(
        () => local.markStageAchieved('goal-1', 's1', other, DateTime.utc(2026)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('storeGoals', () {
    test('replaces the synced rows with the server list', () async {
      await local.createGoal(goal(id: 'stale'), userId);
      await local.reconcileGoalId('stale', goal(id: 'stale'), userId);

      await local.storeGoals([goal(id: 'from-server')], userId);

      expect((await goalsOf(userId)).map((each) => each.id), ['from-server']);
    });

    test('leaves an unsynced local write in place', () async {
      // the whole point: work done offline must survive a pull
      await local.createGoal(goal(id: 'offline', createdAt: DateTime.utc(2026, 3, 1)), userId);

      await local.storeGoals([goal(id: 'from-server', createdAt: DateTime.utc(2026, 1, 1))], userId);

      expect((await goalsOf(userId)).map((each) => each.id), ['from-server', 'offline']);
      expect((await local.unsyncedGoals(userId)).map((each) => each.id), ['offline']);
    });

    test('does not touch another user rows', () async {
      await local.createGoal(goal(id: 'theirs'), other);
      await local.reconcileGoalId('theirs', goal(id: 'theirs'), other);

      await local.storeGoals([goal(id: 'mine')], userId);

      expect((await goalsOf(other)).map((each) => each.id), ['theirs']);
    });

    test('marks everything it stores as synced', () async {
      await local.storeGoals([goal(id: 'from-server')], userId);

      expect(await local.unsyncedGoals(userId), isEmpty);
    });
  });

  group('reconcileGoalId', () {
    test('rewrites the row under the id the server assigned', () async {
      await local.createGoal(goal(id: 'local-1'), userId);

      await local.reconcileGoalId('local-1', goal(id: 'server-1'), userId);

      expect((await goalsOf(userId)).map((each) => each.id), ['server-1']);
      expect(await local.unsyncedGoals(userId), isEmpty);
    });

    test('just marks it synced when the server kept our id', () async {
      await local.createGoal(goal(id: 'local-1'), userId);

      await local.reconcileGoalId('local-1', goal(id: 'local-1'), userId);

      expect((await goalsOf(userId)).map((each) => each.id), ['local-1']);
      expect(await local.unsyncedGoals(userId), isEmpty);
    });
  });

  group('updateGoal', () {
    test('rewrites the definition and drops back to unsynced', () async {
      await local.createGoal(goal(id: 'goal-1'), userId);
      await local.reconcileGoalId('goal-1', goal(id: 'goal-1'), userId);

      await local.updateGoal(
        'goal-1',
        goal(
          id: 'goal-1',
          stages: [GoalStage(id: 's1', target: 200)],
        ),
        userId,
      );

      final read = (await goalsOf(userId)).single;
      expect(read.stages.single.target, 200);
      // it is a local write again until the server confirms it
      expect((await local.unsyncedGoals(userId)).map((each) => each.id), ['goal-1']);
    });
  });

  group('deleteGoal', () {
    test('removes the goal', () async {
      await local.createGoal(goal(id: 'goal-1'), userId);

      await local.deleteGoal('goal-1', userId);

      expect(await goalsOf(userId), isEmpty);
    });

    test('will not delete somebody else goal', () async {
      await local.createGoal(goal(id: 'theirs'), other);

      await local.deleteGoal('theirs', userId);

      expect((await goalsOf(other)).map((each) => each.id), ['theirs']);
    });
  });

  test('stages are stored as the same JSON the wire carries', () async {
    await local.createGoal(
      goal(
        id: 'goal-1',
        stages: [GoalStage(id: 's1', target: 100, dueOn: DateTime.utc(2026, 12, 25))],
      ),
      userId,
    );

    final rows = await db.query('goals', where: 'id = ?', whereArgs: ['goal-1']);
    final stages = jsonDecode(rows.single['stages'] as String) as List;

    // a calendar date, not an instant — Christmas is Christmas wherever you are
    expect(stages.single, {'id': 's1', 'target': 100, 'dueOn': '2026-12-25'});
  });
}
