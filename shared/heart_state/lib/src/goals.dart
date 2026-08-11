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
  /// Replaces the server's view of one slice of this user's goals — live or
  /// archived — marking each one synced and leaving unsynced writes untouched.
  Future<void> storeGoals(Iterable<Goal> goals, String userId, {bool archived});

  /// Goals written locally that the server has not confirmed.
  Future<Iterable<Goal>> unsyncedGoals(String userId);

  /// Rewrites a local row under the id the server gave it, and marks it synced.
  Future<void> reconcileGoalId(String localId, Goal saved, String userId);
}

/// A rung the app has just noticed was met, and the goal it belongs to.
///
/// Returned by [Goals.observeProgress] so a caller can say so — the workout
/// summary congratulates you for the rung the session you just finished earned.
typedef GoalAchievement = ({Goal goal, GoalStage stage});

/// A write the server considered and refused.
///
/// The distinction a local-first list needs is not *which* failure happened but
/// whether repeating it could ever work. An outage, a dropped connection or a
/// 500 are worth retrying forever; a refusal is not — retrying one spends a
/// request on every launch and leaves a goal that looks saved and never will be.
///
/// The server names every failure with a stable [code] for exactly this, so the
/// client branches on identity rather than on prose that may be reworded.
/// `server_error` is the one named failure that is still transient; an unnamed
/// one — no body, a timeout, a proxy's HTML — never reached the handler at all.
class GoalRejected implements Exception {
  /// The server's stable identifier: `goal_limit`, `goal_scope`,
  /// `goal_cadence_stages`, `goal_not_found`, `goal_stage_not_found`, or the
  /// category default a route has not specialised yet.
  final String code;

  /// The server's human sentence, when it sent one.
  final String? reason;

  const GoalRejected(this.code, {this.reason});

  /// The account is already at its cap. The only refusal a *valid* create can
  /// hit on state the app cannot see — a goal made on another device and not
  /// yet pulled — so it is worth saying out loud rather than only reporting.
  bool get isAtCapacity => code == 'goal_limit';

  /// The workout credited with a rung is not one the server will accept — it
  /// belongs to someone else, or this device pushed the stamp before the
  /// workout itself landed.
  ///
  /// The achievement is still real; only the attribution was refused. Worth
  /// telling apart so a stamp can be retried without it rather than dropped.
  bool get isUnknownWorkout => code == 'goal_workout_unknown';

  /// Named, but still transient: the request was fine and the server broke.
  static const _serverError = 'server_error';

  /// Reads a refusal out of whatever the service threw, or null when the
  /// failure could just as well be an outage.
  static GoalRejected? from(Object? error) {
    return switch (error) {
      {'code': _serverError} => null,
      {'code': String code} => GoalRejected(
        code,
        reason: switch (error) {
          {'reason': String reason} => reason,
          {'message': String message} => message,
          _ => null,
        },
      ),
      _ => null,
    };
  }

  @override
  String toString() => reason ?? 'Goal rejected: $code';
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

  /// How many live goals the server will hold for one user.
  ///
  /// Duplicated from the API deliberately — the cap is enforced inside the
  /// `INSERT` (`WHERE count(...) < 50`) and there is no endpoint that reports
  /// it, so the app cannot learn it. Knowing it lets the UI stop offering a
  /// goal it cannot create; the server stays the one that actually enforces it.
  static const maxActive = 50;

  final _goals = <Goal>[];

  /// The achieved surface — goals that have been archived, shown on the back of
  /// the card. A slice, never mixed into [_goals].
  final _archived = <Goal>[];

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

  /// Goals already achieved and put away. Read-only here; the card flips to it.
  List<Goal> get archived => UnmodifiableListView(_archived);

  /// Whether there is an achieved surface worth offering to flip to.
  bool get hasArchived => _archived.isNotEmpty;

  /// Whether the server would refuse another goal.
  ///
  /// Counted locally, so it can disagree with the server when goals were made
  /// on another device and not pulled yet. The create still fails in that case;
  /// this only stops the app offering what it can usually tell is impossible.
  bool get isAtCapacity => _goals.length >= maxActive;

  static Goals of(BuildContext context) => Provider.of<Goals>(context, listen: false);

  static Goals watch(BuildContext context) => Provider.of<Goals>(context, listen: true);

  @override
  void onSignOut() {
    _retired = false;
    _archived.clear();
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

  /// The signed-in user's own goals. Goals are read by *whose* they are now —
  /// the server lets one account see another's — and this app only ever asks
  /// for its own.
  Future<Iterable<Goal>> _mine(String id, {bool archived = false}) {
    return _service.getTargetUserGoals(requesterId: id, targetUserId: id, archived: archived);
  }

  Future<void> _init() async {
    if (userId case String id) {
      try {
        _replace(await _mine(id));
        _archived
          ..clear()
          ..addAll(await _mine(id, archived: true));
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
      initialized = true;
      notifyListeners();

      if (!_pulled) await pull();
      await pushPending();
      await _retireCompleted();
    }
  }

  /// Moves finished goals to the achieved surface — at launch, and only at
  /// launch.
  ///
  /// A goal completed *during* a session stays where the user can see it: it
  /// was just earned, and having it vanish from under them mid-session is the
  /// opposite of a reward. The next launch puts it away. Archiving is what
  /// actually moves it, which is also what frees a slot against the cap.
  ///
  /// Runs once per session, not once per [init]. `init` is called from the
  /// profile screen *and* on every auth-state emission — token refresh included
  /// — so tying retirement to it filed a goal away the moment one of those
  /// landed after it was earned, which is exactly what this is meant to prevent.
  Future<void> _retireCompleted() async {
    if (_retired) return;
    _retired = true;

    final finished = _goals.where((goal) => goal.isComplete).toList();
    for (final goal in finished) {
      await archive(goal);
    }
  }

  /// Whether this session has already filed away what it found finished.
  bool _retired = false;

  /// Server wins for anything it has already confirmed.
  ///
  /// Both slices, because the achieved surface is as authoritative as the live
  /// list and neither is paginated — the cap keeps them small.
  Future<void> pull() async {
    if (userId case String id) {
      try {
        await _service.storeGoals(
          await _remoteService.getTargetUserGoals(requesterId: id, targetUserId: id),
          id,
        );
        await _service.storeGoals(
          await _remoteService.getTargetUserGoals(requesterId: id, targetUserId: id, archived: true),
          id,
          archived: true,
        );
        _replace(await _mine(id));
        _archived
          ..clear()
          ..addAll(await _mine(id, archived: true));
        _pulled = true;
        notifyListeners();
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
  }

  Future<Goal> create(Goal goal) async {
    final id = userId!;
    final local = await _service.createGoal(Goal.inDeadlineOrder(goal), id);
    _goals.add(local);
    notifyListeners();

    // A refused create has nothing on the server to reconcile against, so the
    // local row goes with it — left behind it would retry on every launch and
    // sit in the list looking saved. Rethrown because a create is something the
    // user just asked for and is still watching.
    return _push(local, () => _remoteService.createGoal(local, id), onRejected: _discard);
  }

  Future<Goal> update(Goal goal) async {
    final id = userId!;
    final goalId = goal.id!;

    // A rung added to a finished ladder gives it somewhere left to go, so it
    // belongs back where the user is working. Only ever revives — a goal
    // completed mid-session must not file itself away under them.
    final wasArchived = _archived.any((each) => each.id == goalId);
    if (wasArchived && !goal.isComplete) return revive(goal);

    final local = await _service.updateGoal(goalId, Goal.inDeadlineOrder(goal), id);
    _swap(goalId, local);
    notifyListeners();

    // The server still holds the goal, so it holds the truth: let its version
    // win rather than keeping an edit it has refused.
    return _push(local, () => _remoteService.updateGoal(goalId, local, id), onRejected: _revert);
  }

  /// Puts a finished goal away on the achieved surface.
  ///
  /// Archiving is the move, not a display flag: the server counts only
  /// non-archived goals against the cap, so this is what frees a slot.
  Future<Goal> archive(Goal goal) => _setArchived(goal, true);

  /// Brings an achieved goal back to the live list.
  ///
  /// What adding a rung to a finished ladder does — the goal has somewhere left
  /// to go, so it belongs where the user is working.
  Future<Goal> revive(Goal goal) => _setArchived(goal, false);

  Future<Goal> _setArchived(Goal goal, bool archived) async {
    final id = userId!;
    final goalId = goal.id!;
    // Ordered here too. Reviving comes through this path rather than [update],
    // so without it a rung added to a finished ladder kept the position it was
    // typed in — visible the moment the new one is due before an existing one.
    final moved = Goal.inDeadlineOrder(goal).copyWith(archived: archived);

    final (from, to) = switch (archived) {
      true => (_goals, _archived),
      false => (_archived, _goals),
    };
    from.removeWhere((each) => each.id == goalId);
    to.removeWhere((each) => each.id == goalId);
    to.add(moved);
    notifyListeners();

    final local = await _service.updateGoal(goalId, moved, id);
    return _push(local, () => _remoteService.updateGoal(goalId, local, id), onRejected: _revert);
  }

  Future<void> remove(Goal goal) async {
    final id = userId!;
    final goalId = goal.id!;
    _goals.removeWhere((each) => each.id == goalId);
    _archived.removeWhere((each) => each.id == goalId);
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
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    final id = userId!;
    final local = await _service.markStageAchieved(goalId, stageId, id, achievedAt, achievedBy: achievedBy);
    _swap(goalId, local);
    notifyListeners();

    try {
      return await _push(
        local,
        () => _remoteService.markStageAchieved(goalId, stageId, id, achievedAt, achievedBy: achievedBy),
        onRejected: _revert,
      );
    } on GoalRejected catch (rejection) {
      // The achievement is real; only the credit was refused — the workout is
      // one the server will not accept, usually because this device stamped the
      // rung before the workout itself finished landing. Losing the rung over a
      // link nobody asked for would be the wrong trade, so it is re-sent
      // unattributed. Once.
      if (!rejection.isUnknownWorkout || achievedBy == null) rethrow;
      return markStageAchieved(goalId, stageId, achievedAt);
    }
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
  /// Returns the rungs newly stamped by this pass, in the order they were met,
  /// so the caller can announce them. Empty when nothing changed — which is the
  /// common case, since this runs on every profile build.
  /// [achievedBy] credits a workout with whatever this pass stamps — posterity,
  /// and a link the goal detail renders back to that session. Supplied only
  /// where the answer is known: the workout summary knows which session just
  /// ended, a profile build does not, and a wrong attribution is worse than
  /// none. The server rejects an id the caller does not own.
  Future<List<GoalAchievement>> observeProgress(
    Future<num?> Function(Goal goal) valueOf, {
    String? achievedBy,
  }) async {
    final achieved = <GoalAchievement>[];
    if (userId == null) return achieved;

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

        try {
          final stamped = await markStageAchieved(
            goal.id!,
            stage.id!,
            DateTime.timestamp(),
            achievedBy: achievedBy,
          );
          achieved.add((goal: stamped, stage: stage));
        } on GoalRejected catch (rejection, stacktrace) {
          // Nobody asked for this one — it is the app noticing on the user's
          // behalf — so a refusal is reported, not raised, and the remaining
          // rungs still get their look.
          onError?.call(rejection, stacktrace: stacktrace);
        }
      }
    }

    return achieved;
  }

  /// Recurring goals this session carried over their target.
  ///
  /// Separate from [observeProgress] because nothing is stamped: a cadence goal
  /// resets each period and is never "done", so there is no achievement to
  /// record — only something worth saying once.
  ///
  /// Announced when the session made the difference: with it the period meets
  /// the target, without it the period did not. That is both truer than "is it
  /// met right now" and self-limiting — a later session in the same period
  /// cannot re-announce, because by then the period already met the target
  /// without it. No marker to persist, and nothing to reset when the week
  /// rolls over.
  Future<List<GoalAchievement>> observePeriodWins({
    required Future<num?> Function(Goal goal) valueOf,
    required Future<num?> Function(Goal goal) valueBefore,
  }) async {
    final wins = <GoalAchievement>[];
    if (userId == null) return wins;

    for (final goal in List.of(_goals)) {
      if (goal.cadence == null) continue;
      // the db gives a cadence goal exactly one stage
      final stage = goal.stages.firstOrNull;
      if (stage == null) continue;

      final num? now;
      final num? before;
      try {
        now = await valueOf(goal);
        before = await valueBefore(goal);
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
        continue;
      }

      if (now == null) continue;
      if (!_meets(stage, now, goal.metric.lowerIsBetter)) continue;
      // already there without this session, so this session is not the news
      if (before != null && _meets(stage, before, goal.metric.lowerIsBetter)) continue;

      wins.add((goal: goal, stage: stage));
    }

    return wins;
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
          await _push(goal, () => _remoteService.createGoal(goal, id), onRejected: _discard);
        }
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
  }

  /// Sends [send] to the server and adopts whatever comes back — the server
  /// mints the authoritative id.
  ///
  /// A failure the server never saw leaves [local] standing and unsynced, to be
  /// retried; one it saw and refused is handed to [onRejected] to undo, because
  /// retrying it forever would only keep failing.
  Future<Goal> _push(
    Goal local,
    Future<Goal> Function() send, {
    required Future<void> Function(Goal local) onRejected,
  }) async {
    final id = userId!;
    try {
      final saved = await send();
      await _service.reconcileGoalId(local.id!, saved, id);
      _swap(local.id!, saved);
      notifyListeners();
      return saved;
    } catch (error, stacktrace) {
      if (GoalRejected.from(error) case GoalRejected rejection) {
        await onRejected(local);
        throw rejection;
      }
      onError?.call(error, stacktrace: stacktrace);
      return local;
    }
  }

  /// Undoes a refused create: the goal exists nowhere else.
  Future<void> _discard(Goal local) async {
    _goals.removeWhere((each) => each.id == local.id);
    _archived.removeWhere((each) => each.id == local.id);
    notifyListeners();
    if (userId case String id) {
      await _service.deleteGoal(local.id!, id);
    }
  }

  /// Undoes a refused edit by re-reading the goals the server will admit to.
  Future<void> _revert(Goal local) => pull();

  void _replace(Iterable<Goal> goals) {
    _goals
      ..clear()
      ..addAll(goals);
  }

  /// Replaces a goal wherever it currently sits.
  ///
  /// Both slices, because a push can land on either — reconciling an archive
  /// against [_goals] alone would find nothing and put the goal straight back
  /// on the live list.
  void _swap(String goalId, Goal replacement) {
    for (final slice in [_goals, _archived]) {
      final at = slice.indexWhere((each) => each.id == goalId);
      if (at != -1) {
        slice[at] = replacement;
        return;
      }
    }

    // not held yet: a create whose id the server has just minted
    switch (replacement.archived) {
      case true:
        _archived.add(replacement);
      case false:
        _goals.add(replacement);
    }
  }
}
