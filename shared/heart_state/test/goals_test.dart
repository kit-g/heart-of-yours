import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/goals.dart';

void main() {
  late _FakeLocal local;
  late _FakeRemote remote;
  late List<Object> errors;
  late Goals sut;

  const userId = 'user-123';

  Goal ladder({String? id, num target = 100, String? stageId}) {
    return Goal(
      id: id,
      metric: .topSetWeight,
      exerciseId: 'exercise-1',
      stages: [GoalStage(id: stageId, target: target)],
    );
  }

  void build() {
    errors = [];
    local = _FakeLocal();
    remote = _FakeRemote();
    sut = Goals(
      service: local,
      remoteService: remote,
      onError: (error, {stacktrace}) => errors.add(error),
    )..userId = userId;
  }

  setUp(build);

  group('init', () {
    test('paints from the local mirror before reaching the server', () async {
      local.goals.add(ladder(id: 'local-1'));
      remote.goals.add(ladder(id: 'server-1'));

      final painted = <int>[];
      sut.addListener(() => painted.add(sut.length));

      await sut.init();

      // one notify with the local row, one after the server reconciles
      expect(painted.first, 1);
      expect(sut.single.id, 'server-1');
      expect(sut.initialized, isTrue);
    });

    test('survives a dead network, keeping what is stored locally', () async {
      local.goals.add(ladder(id: 'local-1'));
      remote.failing = true;

      await sut.init();

      expect(sut.single.id, 'local-1');
      expect(errors, isNotEmpty);
    });

    test('retries a failed pull, and stops retrying once one succeeds', () async {
      // the first request of a launch can lose a race with token refresh.
      // A pull reads both slices — the live list and the achieved surface — so
      // a successful one costs two reads and a failed one stops at the first.
      remote.failing = true;
      await sut.init();
      expect(remote.reads, 1);

      remote.failing = false;
      remote.goals.add(ladder(id: 'server-1'));
      await sut.init();
      expect(remote.reads, 3);
      expect(sut.single.id, 'server-1');

      await sut.init();
      expect(remote.reads, 3, reason: 'a pull that succeeded is never repeated');
    });
  });

  group('observePeriodWins', () {
    Goal weekly({num target = 2000}) {
      return Goal(
        id: 'goal-w',
        metric: .totalVolume,
        exerciseId: 'exercise-1',
        cadence: .week,
        stages: [GoalStage(id: 's0', target: target)],
      );
    }

    Future<List<GoalAchievement>> observe({required num now, required num before}) {
      return sut.observePeriodWins(
        valueOf: (_) async => now,
        valueBefore: (_) async => before,
      );
    }

    Future<void> seedWeekly() async {
      final goal = weekly();
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();
    }

    test('announces the session that carried the period over', () async {
      await seedWeekly();

      final wins = await observe(now: 2160, before: 1200);

      expect(wins, hasLength(1));
      expect(wins.single.goal.id, 'goal-w');
    });

    test('stays quiet for a later session in a period already won', () async {
      // otherwise it congratulates you again every workout until the week ends
      await seedWeekly();

      expect(await observe(now: 3000, before: 2400), isEmpty);
    });

    test('stays quiet while the period is still short', () async {
      await seedWeekly();

      expect(await observe(now: 1800, before: 900), isEmpty);
    });

    test('stamps nothing — a recurring goal is never done', () async {
      await seedWeekly();

      await observe(now: 2160, before: 1200);

      expect(local.achieved, isEmpty);
      expect(remote.achieved, isEmpty);
      expect(sut.single.stages.single.isAchieved, isFalse);
    });

    test('leaves milestones to observeProgress', () async {
      final milestone = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(milestone);
      remote.goals.add(milestone);
      await sut.init();

      expect(await observe(now: 120, before: 0), isEmpty);
    });
  });

  group('the achieved surface', () {
    Goal done({String id = 'goal-1'}) {
      return Goal(
        id: id,
        metric: .topSetWeight,
        exerciseId: 'exercise-1',
        stages: [GoalStage(id: '${id}s', target: 100, achievedAt: DateTime.utc(2026, 8, 1))],
      );
    }

    test('files a finished goal away at launch', () async {
      // archiving is the move, not a display flag — it is what frees a slot
      // against the server's cap
      final finished = done();
      local.goals.add(finished);
      remote.goals.add(finished);

      await sut.init();

      expect(sut, isEmpty);
      expect(sut.archived.map((each) => each.id), ['goal-1']);
      expect(sut.hasArchived, isTrue);
    });

    test('leaves a goal finished mid-session where the user can see it', () async {
      // it was just earned; having it vanish from under them is the opposite
      // of a reward. The next launch puts it away.
      final live = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(live);
      remote.goals.add(live);
      await sut.init();

      await sut.observeProgress((_) async => 120);

      expect(sut.single.id, 'goal-1');
      expect(sut.archived, isEmpty);
    });

    test('leaves a mid-session win alone even when init runs again', () async {
      // `init` fires from the profile screen and on every auth-state emission,
      // token refresh included — retirement must not ride along with it, or the
      // goal is filed away moments after it is earned
      final live = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(live);
      remote.goals.add(live);
      await sut.init();

      await sut.observeProgress((_) async => 120);
      expect(sut.single.id, 'goal-1');

      await sut.init();

      expect(sut.single.id, 'goal-1', reason: 'still where the user can see it');
      expect(sut.archived, isEmpty);
    });

    test('files it away on the next session', () async {
      final live = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(live);
      remote.goals.add(live);
      await sut.init();
      await sut.observeProgress((_) async => 120);

      // a fresh launch: same store, new notifier
      final next = Goals(service: local, remoteService: remote)..userId = userId;
      await next.init();

      expect(next, isEmpty);
      expect(next.archived.map((each) => each.id), ['goal-1']);
    });

    test('a rung added to a finished goal brings it back', () async {
      final finished = done();
      local.goals.add(finished);
      remote.goals.add(finished);
      await sut.init();
      expect(sut.archived, hasLength(1));

      final revived = sut.archived.single;
      await sut.update(
        revived.copyWith(
          stages: [
            ...revived.stages,
            GoalStage(id: 's2', target: 120),
          ],
        ),
      );

      expect(sut.single.id, 'goal-1');
      expect(sut.archived, isEmpty);
    });

    test('an edit to a still-finished goal leaves it filed away', () async {
      // only ever revives: editing an achieved goal must not drag it back
      final finished = done();
      local.goals.add(finished);
      remote.goals.add(finished);
      await sut.init();

      final filed = sut.archived.single;
      await sut.update(filed.copyWith(stages: [filed.stages.single.copyWith(target: 110)]));

      expect(sut, isEmpty);
      expect(sut.archived, hasLength(1));
    });

    test('deleting from the achieved surface removes it there too', () async {
      final finished = done();
      local.goals.add(finished);
      remote.goals.add(finished);
      await sut.init();

      await sut.remove(sut.archived.single);

      expect(sut.archived, isEmpty);
      expect(sut.hasArchived, isFalse);
    });

    test('an archived goal does not count against the cap', () async {
      final finished = done();
      local.goals.add(finished);
      remote.goals.add(finished);

      await sut.init();

      expect(sut.isAtCapacity, isFalse);
      expect(sut, isEmpty, reason: 'the live list is what the cap counts');
    });
  });

  group('create', () {
    test('writes locally first, then adopts the id the server mints', () async {
      remote.mintedId = 'server-9';

      final created = await sut.create(ladder());

      expect(local.created, hasLength(1));
      expect(created.id, 'server-9');
      expect(sut.single.id, 'server-9');
      expect(local.reconciled, contains('server-9'));
    });

    test('keeps the local goal when the push fails', () async {
      remote.failing = true;

      final created = await sut.create(ladder());

      // the local row stands and stays unsynced, to be retried next launch
      expect(created.id, local.created.single.id);
      expect(sut, hasLength(1));
      expect(errors, isNotEmpty);
    });

    test('drops the goal the server refused, rather than retrying it forever', () async {
      // the account was already full — filled on another device, so the app had
      // no way to know before asking
      remote.refusal = {'error': 'bad request', 'code': 'goal_limit', 'reason': 'at most 50 active goals'};

      await expectLater(
        sut.create(ladder()),
        throwsA(isA<GoalRejected>().having((e) => e.isAtCapacity, 'isAtCapacity', isTrue)),
      );

      // gone from the list and from the database: kept, it would sit there
      // looking saved and re-POST on every launch
      expect(sut, isEmpty);
      expect(local.deleted, hasLength(1));
    });

    test('tells a refusal apart from the server falling over', () async {
      // named, but not a refusal — the request was fine and the server broke
      remote.refusal = {'error': 'server error', 'code': 'server_error'};

      final created = await sut.create(ladder());

      expect(created.id, local.created.single.id);
      expect(sut, hasLength(1));
      expect(local.deleted, isEmpty);
    });

    test('clears a refused pending goal instead of pushing it again', () async {
      local.unsynced.add(ladder(id: 'local-1'));
      remote.refusal = {'error': 'bad request', 'code': 'goal_limit', 'reason': 'at most 50 active goals'};

      await sut.pushPending();

      expect(local.deleted, contains('local-1'));
    });
  });

  test('concurrent inits share one run, so an unsynced goal is pushed once', () async {
    // init() fires from both the profile screen and the auth callback; each
    // pass used to POST the same unsynced row, minting a duplicate server-side
    local.unsynced.add(ladder(id: 'local-1'));
    remote.mintedId = 'server-1';

    await Future.wait([sut.init(), sut.init()]);

    expect(remote.created, hasLength(1));
  });

  group('deadline order', () {
    Goal withRungs(List<(num, DateTime?)> rungs, {GoalMetric metric = GoalMetric.topSetWeight}) {
      return Goal(
        id: 'goal-1',
        metric: metric,
        exerciseId: 'exercise-1',
        stages: [
          for (final (index, (target, due)) in rungs.indexed) GoalStage(id: 's$index', target: target, dueOn: due),
        ],
      );
    }

    List<num> targetsOf(Goal goal) => goal.stages.map((each) => each.target).toList();

    DateTime day(int month) => DateTime(2026, month, 1);

    test('orders rungs by when they come due, not by how big they are', () async {
      // the ladder that prompted this: bigger targets falling sooner
      await sut.create(
        withRungs([
          (12, day(12)),
          (14, day(10)),
          (16, day(8)),
        ]),
      );

      expect(targetsOf(local.created.single), [16, 14, 12]);
    });

    test('leaves a descending ladder alone — that is a real intention', () async {
      // strong enough, light enough, and no further
      await sut.create(
        withRungs([
          (85, day(3)),
          (82, day(6)),
          (78, day(9)),
        ]),
      );

      expect(targetsOf(local.created.single), [85, 82, 78]);
    });

    test('sorts an undated rung last, since it is the open-ended one', () async {
      await sut.create(
        withRungs([
          (100, null),
          (120, day(5)),
        ]),
      );

      expect(targetsOf(local.created.single), [120, 100]);
    });

    test('reorders on update too, since an edit can move a deadline', () async {
      final goal = withRungs([
        (12, day(6)),
        (14, day(9)),
      ]);
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();

      // the later rung pulled forward
      await sut.update(
        withRungs([
          (12, day(6)),
          (14, day(3)),
        ]),
      );

      expect(targetsOf(sut.single), [14, 12]);
    });

    test('leaves a single rung alone', () async {
      await sut.create(withRungs([(100, null)]));

      expect(targetsOf(local.created.single), [100]);
    });
  });

  group('observeProgress', () {
    Goal ladderOf(List<num> targets, {GoalMetric metric = GoalMetric.topSetWeight}) {
      return Goal(
        id: 'goal-1',
        metric: metric,
        exerciseId: 'exercise-1',
        stages: [
          for (final (index, target) in targets.indexed) GoalStage(id: 's$index', target: target),
        ],
      );
    }

    /// On both sides before init: a pull is authoritative for synced rows, so
    /// seeding only the local mirror leaves the list empty and every assertion
    /// about "nothing was stamped" passes for the wrong reason.
    Future<void> seed(List<Goal> goals) {
      local.goals.addAll(goals);
      remote.goals.addAll(goals);
      return sut.init();
    }

    Future<void> observe(num? value) {
      return sut.observeProgress((_) async => value);
    }

    test('credits the workout that earned the rung', () async {
      // posterity, and the link the goal detail renders back to that session
      final goal = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();

      await sut.observeProgress((_) async => 120, achievedBy: 'workout-7');

      expect(local.attributed, ['workout-7']);
      expect(remote.attributed, ['workout-7']);
    });

    test('attributes nothing when the caller does not know the session', () async {
      // a profile build has no workout in hand, and a wrong attribution is
      // worse than none — the server would reject an id we do not own anyway
      final goal = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();

      await sut.observeProgress((_) async => 120);

      expect(local.attributed, [null]);
    });

    test('keeps the rung when the server refuses only the attribution', () async {
      // the workout is one the server will not credit — the achievement itself
      // is still real, so it goes again without the link rather than being lost
      final goal = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();

      remote.refusalOnAttribution = {
        'error': 'bad request',
        'code': 'goal_workout_unknown',
        'reason': 'no such workout',
      };

      await sut.observeProgress((_) async => 120, achievedBy: 'workout-gone');

      expect(remote.achieved, contains('stage-1'));
      expect(remote.attributed.last, isNull, reason: 'the retry drops the credit');
    });

    test('reports the rungs it stamped, so the caller can announce them', () async {
      // the workout summary congratulates you for exactly these
      final goal = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();

      final earned = await sut.observeProgress((_) async => 120);

      expect(earned, hasLength(1));
      expect(earned.single.stage.id, 'stage-1');
      expect(earned.single.goal.id, 'goal-1');
    });

    test('reports nothing when nothing new was met', () async {
      // the common case: this runs on every profile build
      final goal = ladder(id: 'goal-1', stageId: 'stage-1', target: 100);
      local.goals.add(goal);
      remote.goals.add(goal);
      await sut.init();

      expect(await sut.observeProgress((_) async => 50), isEmpty);
    });

    test('stamps a rung once its target is met', () async {
      await seed([
        ladderOf([100]),
      ]);

      await observe(100);

      expect(local.achieved, ['s0']);
      expect(sut.single.stages.single.isAchieved, isTrue);
    });

    test('leaves a rung alone below its target', () async {
      await seed([
        ladderOf([100]),
      ]);

      await observe(99.5);

      expect(local.achieved, isEmpty);
    });

    test('clears two rungs at once when the value passes both', () async {
      await seed([
        ladderOf([100, 120]),
      ]);

      await observe(125);

      expect(local.achieved, ['s0', 's1']);
    });

    test('does not re-stamp, so the timestamp stays the first observation', () async {
      await seed([
        ladderOf([100]),
      ]);

      await observe(120);
      local.achieved.clear();
      await observe(130);

      expect(local.achieved, isEmpty);
    });

    test('skips recurring goals, which are never done', () async {
      await seed([
        Goal(
          id: 'goal-1',
          metric: .workouts,
          cadence: .week,
          stages: [GoalStage(id: 's0', target: 4)],
        ),
      ]);

      await observe(9);

      expect(local.achieved, isEmpty);
    });

    test('meets a pace rung from above, since lower is better there', () async {
      await seed([
        ladderOf([300], metric: .averagePace),
      ]);

      await observe(280);

      expect(local.achieved, ['s0']);
    });

    test('skips a goal whose value cannot be measured', () async {
      await seed([
        ladderOf([100]),
      ]);

      await observe(null);

      expect(local.achieved, isEmpty);
    });

    test('one goal failing to measure does not stop the rest', () async {
      await seed([
        ladderOf([100]),
        Goal(
          id: 'goal-2',
          metric: .topSetWeight,
          exerciseId: 'e2',
          stages: [GoalStage(id: 'x0', target: 50)],
        ),
      ]);

      await sut.observeProgress((goal) async {
        if (goal.id == 'goal-1') throw StateError('no history');
        return 60;
      });

      expect(local.achieved, ['x0']);
      expect(errors, isNotEmpty);
    });
  });

  test('pushPending retries goals the server never confirmed', () async {
    local.unsynced.add(ladder(id: 'local-1'));
    remote.mintedId = 'server-1';

    await sut.pushPending();

    expect(remote.created, hasLength(1));
    expect(local.reconciled, contains('server-1'));
  });

  test('a refused edit lets the server\'s version win', () async {
    final goal = ladder(id: 'goal-1');
    local.goals.add(goal);
    remote.goals.add(goal);
    await sut.init();

    // a recurring goal gets exactly one rung; a second is a request the server
    // will never accept, so the edit cannot simply be left to retry
    remote.refusal = {'error': 'bad request', 'code': 'goal_cadence_stages', 'reason': 'one stage per cadence goal'};

    await expectLater(
      sut.update(
        goal.copyWith(
          stages: [
            ...goal.stages,
            GoalStage(id: 's2', target: 200),
          ],
        ),
      ),
      throwsA(isA<GoalRejected>()),
    );

    // the pull that follows re-reads the goals the server admits to — the fake
    // is still refusing, so the edit stands locally but nothing was deleted
    expect(local.deleted, isEmpty);
  });

  test('markStageAchieved stamps locally and pushes', () async {
    final goal = ladder(id: 'goal-1', stageId: 'stage-1');
    // on both sides: init() pulls, and the server's list is authoritative for
    // anything already synced
    local.goals.add(goal);
    remote.goals.add(goal);
    await sut.init();

    final at = DateTime.utc(2026, 12, 25);
    await sut.markStageAchieved('goal-1', 'stage-1', at);

    expect(local.achieved, contains('stage-1'));
    expect(remote.achieved, contains('stage-1'));
  });
}

class _FakeLocal implements LocalGoalService {
  final goals = <Goal>[];
  final created = <Goal>[];
  final unsynced = <Goal>[];
  final reconciled = <String>[];
  final achieved = <String>[];
  final attributed = <String?>[];
  final stored = <Goal>[];
  final deleted = <String>[];

  var _minted = 0;

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    return goals.where((each) => each.archived == archived).toList();
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    final stamped = goal.copyWith(id: goal.id ?? 'local-${++_minted}');
    created.add(stamped);
    goals.add(stamped);
    return stamped;
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    return goal.copyWith(id: goalId);
  }

  @override
  Future<void> deleteGoal(String goalId, String userId) async {
    deleted.add(goalId);
    goals.removeWhere((each) => each.id == goalId);
  }

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    achieved.add(stageId);
    attributed.add(achievedBy);
    final goal = goals.firstWhere((each) => each.id == goalId);
    return goal.copyWith(
      stages: goal.stages.map((s) => s.id == stageId ? s.copyWith(achievedAt: achievedAt) : s).toList(),
    );
  }

  @override
  Future<void> storeGoals(Iterable<Goal> goals, String userId, {bool archived = false}) async {
    stored.addAll(goals);
    // one slice at a time, as the database does — replacing the whole list here
    // would let the live pull wipe the achieved surface
    this.goals
      ..removeWhere((each) => each.archived == archived)
      ..addAll(goals);
  }

  @override
  Future<Iterable<Goal>> unsyncedGoals(String userId) async => List.of(unsynced);

  @override
  Future<void> reconcileGoalId(String localId, Goal saved, String userId) async {
    reconciled.add(saved.id!);
  }
}

class _FakeRemote implements GoalService {
  final goals = <Goal>[];
  final created = <Goal>[];
  final achieved = <String>[];
  final attributed = <String?>[];

  bool failing = false;
  String? mintedId;

  /// The error body a refusal arrives as: a stable `code` beside the prose.
  /// Set to make the fake refuse instead of going dark.
  Map<String, dynamic>? refusal;

  /// Refuses only a stamp that credits a workout, the way the server rejects an
  /// `achievedBy` it does not recognise.
  Map<String, dynamic>? refusalOnAttribution;

  void _guard() {
    if (refusal case Map<String, dynamic> body) throw body;
    if (failing) throw StateError('network is down');
  }

  int reads = 0;

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    reads++;
    _guard();
    return goals.where((each) => each.archived == archived).toList();
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    _guard();
    created.add(goal);
    return goal.copyWith(id: mintedId ?? goal.id);
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    _guard();
    return goal.copyWith(id: goalId);
  }

  @override
  Future<void> deleteGoal(String goalId, String userId) async => _guard();

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    _guard();
    if (achievedBy != null) {
      if (refusalOnAttribution case final Map<String, dynamic> body) {
        attributed.add(achievedBy);
        throw body;
      }
    }
    achieved.add(stageId);
    attributed.add(achievedBy);

    // the stamped goal, as the endpoint returns it — handing back the stored
    // copy instead makes the caller overwrite the achievement it just recorded
    final goal = goals.firstWhere(
      (each) => each.id == goalId,
      orElse: () => Goal(id: goalId, metric: .topSetWeight, exerciseId: 'e', stages: [GoalStage(target: 1)]),
    );
    final stamped = goal.copyWith(
      stages: goal.stages.map((s) => s.id == stageId ? s.copyWith(achievedAt: achievedAt) : s).toList(),
    );
    goals
      ..removeWhere((each) => each.id == goalId)
      ..add(stamped);
    return stamped;
  }
}
