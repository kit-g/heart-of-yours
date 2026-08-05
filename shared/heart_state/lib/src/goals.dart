import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

/// The local half of goal storage.
///
/// [GoalService] covers what both ends can do; these three are the bookkeeping
/// local-first sync needs and the server has no use for. It lives here rather
/// than in `heart_models` so this package keeps depending on nothing but model
/// interfaces — `LocalDatabase` satisfies it through an adapter in the app.
abstract interface class LocalGoalService implements GoalService {
  /// Replaces the server's view of this user's goals, marking each one synced
  /// and leaving unsynced local writes untouched.
  Future<void> storeGoals(Iterable<Goal> goals, String userId);

  /// Goals written locally that the server has not confirmed.
  Future<Iterable<Goal>> unsyncedGoals(String userId);

  /// Rewrites a local row under the id the server gave it, and marks it synced.
  Future<void> reconcileGoalId(String localId, Goal saved, String userId);
}

/// The user's goals, written locally first so they survive a dead network.
///
/// Definitions live on the server; **progress does not** — every goal is
/// measured against stats the app already computes in SQLite, so a goal reads
/// correctly offline. The server's one job beyond storage is remembering that a
/// stage was achieved, which is why [markStageAchieved] pushes.
class Goals with ChangeNotifier, Iterable<Goal> implements SignOutStateSentry {
  final LocalGoalService _service;
  final GoalService _remoteService;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  final _goals = <Goal>[];

  String? userId;

  bool initialized = false;

  /// Whether a server pull has ever succeeded this session.
  ///
  /// The first request after launch can lose a race with token refresh — the
  /// gateway then answers with a non-JSON body and the decode throws. Without
  /// this, that one failure left the card showing only local goals until the
  /// app was relaunched; with it, the next [init] tries again and a successful
  /// pull is never repeated.
  bool _pulled = false;

  Goals({
    required LocalGoalService service,
    required GoalService remoteService,
    this.onError,
  }) : _service = service,
       _remoteService = remoteService;

  @override
  Iterator<Goal> get iterator => _goals.iterator;

  List<Goal> get all => UnmodifiableListView(_goals);

  static Goals of(BuildContext context) => Provider.of<Goals>(context, listen: false);

  static Goals watch(BuildContext context) => Provider.of<Goals>(context, listen: true);

  @override
  void onSignOut() {
    _goals.clear();
    userId = null;
    initialized = false;
    _pulled = false;
    _initializing = null;
  }

  /// Paints from the local mirror, then reconciles with the server and retries
  /// anything written while offline. Local first so the card is never blank
  /// waiting on a request.
  ///
  /// Called from two places — the profile screen's first layout and the moment
  /// auth settles — so concurrent callers share one run. Without that they each
  /// reach [pushPending] with the same unsynced row and the server mints a goal
  /// for both, which is how duplicates appeared.
  Future<void> init() {
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<void>? _initializing;

  Future<void> _init() async {
    if (userId case String id) {
      try {
        _replace(await _service.getGoals(id));
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
      initialized = true;
      notifyListeners();

      if (!_pulled) await pull();
      await pushPending();
    }
  }

  /// Server wins for anything it has already confirmed.
  Future<void> pull() async {
    if (userId case String id) {
      try {
        await _service.storeGoals(await _remoteService.getGoals(id), id);
        _replace(await _service.getGoals(id));
        _pulled = true;
        notifyListeners();
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
  }

  Future<Goal> create(Goal goal) async {
    final id = userId!;
    final local = await _service.createGoal(goal, id);
    _goals.add(local);
    notifyListeners();

    return _push(local, () => _remoteService.createGoal(local, id));
  }

  Future<Goal> update(Goal goal) async {
    final id = userId!;
    final goalId = goal.id!;
    final local = await _service.updateGoal(goalId, goal, id);
    _swap(goalId, local);
    notifyListeners();

    return _push(local, () => _remoteService.updateGoal(goalId, local, id));
  }

  Future<void> remove(Goal goal) async {
    final id = userId!;
    final goalId = goal.id!;
    _goals.removeWhere((each) => each.id == goalId);
    notifyListeners();

    await _service.deleteGoal(goalId, id);
    try {
      await _remoteService.deleteGoal(goalId, id);
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Stamps a stage the first time the app observes its target being met.
  /// Idempotent on both ends, so a re-observation is harmless.
  Future<Goal> markStageAchieved(String goalId, String stageId, DateTime achievedAt) async {
    final id = userId!;
    final local = await _service.markStageAchieved(goalId, stageId, id, achievedAt);
    _swap(goalId, local);
    notifyListeners();

    return _push(local, () => _remoteService.markStageAchieved(goalId, stageId, id, achievedAt));
  }

  /// Records every rung whose target the user has now met.
  ///
  /// Progress is computed locally, so nothing here knows how to measure a goal
  /// — [valueOf] resolves a goal's current value in stored units, and this
  /// decides what that means. Keeping the measuring outside is what lets the
  /// rule be tested without a database, a chart or a workout.
  ///
  /// - Recurring goals are skipped: a cadence goal resets each period and is
  ///   never "done", which is why the server gives it exactly one stage.
  /// - Every unachieved rung is checked, not just the current one, so a single
  ///   session that clears two at once records both.
  /// - Already-stamped rungs are left alone, so the timestamp keeps saying when
  ///   the target was *first* met rather than when the app last looked.
  Future<void> observeProgress(Future<num?> Function(Goal goal) valueOf) async {
    if (userId == null) return;

    for (final goal in List.of(_goals)) {
      if (goal.cadence != null || goal.isComplete || goal.id == null) continue;

      final num? value;
      try {
        value = await valueOf(goal);
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
        continue;
      }
      if (value == null) continue;

      for (final stage in goal.stages) {
        if (stage.isAchieved || stage.id == null) continue;
        if (!_meets(stage, value, goal.metric.lowerIsBetter)) continue;

        await markStageAchieved(goal.id!, stage.id!, DateTime.timestamp());
      }
    }
  }

  /// Pace is the one metric where progress means going down, so its rungs are
  /// met from above.
  bool _meets(GoalStage stage, num value, bool lowerIsBetter) {
    return switch (lowerIsBetter) {
      true => value <= stage.target,
      false => value >= stage.target,
    };
  }

  /// Re-attempts the push for goals persisted locally but never confirmed —
  /// a write made offline, or one that hit a flaky network. Failures are left
  /// unsynced to retry next launch; nothing is ever dropped.
  ///
  /// Never runs twice at once: each pass POSTs rows the previous pass has not
  /// yet reconciled, and the server mints a fresh id every time.
  Future<void> pushPending() async {
    if (_pushing) return;
    _pushing = true;
    try {
      await _pushPending();
    } finally {
      _pushing = false;
    }
  }

  bool _pushing = false;

  Future<void> _pushPending() async {
    if (userId case String id) {
      try {
        for (final goal in await _service.unsyncedGoals(id)) {
          await _push(goal, () => _remoteService.createGoal(goal, id));
        }
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
  }

  /// Sends [send] to the server and adopts whatever comes back — the server
  /// mints the authoritative id. On failure [local] stands and stays unsynced.
  Future<Goal> _push(Goal local, Future<Goal> Function() send) async {
    final id = userId!;
    try {
      final saved = await send();
      await _service.reconcileGoalId(local.id!, saved, id);
      _swap(local.id!, saved);
      notifyListeners();
      return saved;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return local;
    }
  }

  void _replace(Iterable<Goal> goals) {
    _goals
      ..clear()
      ..addAll(goals);
  }

  void _swap(String goalId, Goal replacement) {
    final index = _goals.indexWhere((each) => each.id == goalId);
    switch (index) {
      case -1:
        _goals.add(replacement);
      case final at:
        _goals[at] = replacement;
    }
  }
}
