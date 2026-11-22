part of '../api.dart';

/// Goals, and someone else's when they share them.
mixin _GoalRoutes on Requests implements GoalService {
  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    // Reading goals is scoped by whose they are — the same shape workouts use,
    // where asking for your own id is the first allowed case. `archived` picks
    // a slice rather than widening one: true returns only the achieved goals.
    final path = Router.userGoals(targetUserId);
    final response = await get(
      path,
      // as a query parameter, not glued onto the path — `Uri.https` encodes the
      // path, so a `?` in it arrives as `%3F` and the server sees one long path
      // segment that matches no route
      query: switch (archived) {
        true => const {'archived': 'true'},
        false => null,
      },
    );
    final (goals, _) = _listIn(response, 'goals', from: path);
    // A failure is thrown, never answered as no goals: the caller replaces its
    // synced slice with this list, and an empty one would delete every goal it
    // holds. A goal of a kind a newer build added costs that goal, not the
    // list (#277).
    return _readable(goals, Goal.fromJson);
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    return (await replayGoal(goal)).row;
  }

  /// See [replayWorkout]. A refusal is a [ServerRefusal] with a stable
  /// `code`, so the caller can tell one from an outage instead of retrying
  /// both forever.
  Future<({Goal row, bool created})> replayGoal(Goal goal) async {
    final (json, created) = _created(
      await post(
        Router.goals,
        // the client's id rides on a create only — an update addresses its
        // goal by path, and the server preserves the id it was first given
        body: {'id': ?goal.id, ...goal.toBody()},
      ),
    );
    return (row: Goal.fromJson(json), created: created);
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    final (json, _) = await put(Router.goal(goalId), body: goal.toBody());
    return Goal.fromJson(json);
  }

  @override
  Future<void> deleteGoal(String goalId, String userId) => delete(Router.goal(goalId));

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    final (json, _) = await put(
      Router.goalStage(goalId, stageId),
      body: {
        'achievedAt': achievedAt.toUtc().toIso8601String(),
        // the workout credited with the rung; the server rejects one the
        // caller does not own, so it is sent only when we have it
        'achievedBy': ?achievedBy,
      },
    );
    return Goal.fromJson(json);
  }
}
