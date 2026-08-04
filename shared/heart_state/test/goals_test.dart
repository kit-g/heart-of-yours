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
      // the first request of a launch can lose a race with token refresh
      remote.failing = true;
      await sut.init();
      expect(remote.reads, 1);

      remote.failing = false;
      remote.goals.add(ladder(id: 'server-1'));
      await sut.init();
      expect(remote.reads, 2);
      expect(sut.single.id, 'server-1');

      await sut.init();
      expect(remote.reads, 2, reason: 'a pull that succeeded is never repeated');
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
  });

  test('concurrent inits share one run, so an unsynced goal is pushed once', () async {
    // init() fires from both the profile screen and the auth callback; each
    // pass used to POST the same unsynced row, minting a duplicate server-side
    local.unsynced.add(ladder(id: 'local-1'));
    remote.mintedId = 'server-1';

    await Future.wait([sut.init(), sut.init()]);

    expect(remote.created, hasLength(1));
  });

  test('pushPending retries goals the server never confirmed', () async {
    local.unsynced.add(ladder(id: 'local-1'));
    remote.mintedId = 'server-1';

    await sut.pushPending();

    expect(remote.created, hasLength(1));
    expect(local.reconciled, contains('server-1'));
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
  final stored = <Goal>[];

  var _minted = 0;

  @override
  Future<Iterable<Goal>> getGoals(String userId) async => List.of(goals);

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
    goals.removeWhere((each) => each.id == goalId);
  }

  @override
  Future<Goal> markStageAchieved(String goalId, String stageId, String userId, DateTime achievedAt) async {
    achieved.add(stageId);
    final goal = goals.firstWhere((each) => each.id == goalId);
    return goal.copyWith(
      stages: goal.stages.map((s) => s.id == stageId ? s.copyWith(achievedAt: achievedAt) : s).toList(),
    );
  }

  @override
  Future<void> storeGoals(Iterable<Goal> goals, String userId) async {
    stored.addAll(goals);
    this.goals
      ..clear()
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

  bool failing = false;
  String? mintedId;

  void _guard() {
    if (failing) throw StateError('network is down');
  }

  int reads = 0;

  @override
  Future<Iterable<Goal>> getGoals(String userId) async {
    reads++;
    _guard();
    return List.of(goals);
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
  Future<Goal> markStageAchieved(String goalId, String stageId, String userId, DateTime achievedAt) async {
    _guard();
    achieved.add(stageId);
    return goals.firstWhere(
      (each) => each.id == goalId,
      orElse: () => Goal(id: goalId, metric: .topSetWeight, exerciseId: 'e', stages: [GoalStage(target: 1)]),
    );
  }
}
