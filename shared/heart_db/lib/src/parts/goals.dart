part of '../../heart_db.dart';

/// The local mirror of the user's goals.
///
/// Implements the same [GoalService] the remote API does, so [Goals] in
/// `heart_state` can hold one of each and write locally first — the pattern
/// workouts already use. Rows carry a `synced` flag; anything still 0 is a
/// write the server has not confirmed.
mixin _Goals on _LocalDatabase implements GoalService {
  @override
  Future<Iterable<Goal>> getGoals(String userId) {
    return _db
        .query(
          _goals,
          where: 'user_id = ? AND archived = 0',
          whereArgs: [userId],
          orderBy: 'created_at',
        )
        .then((rows) => rows.map(Goal.fromRow));
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    // A goal written offline needs a key now — both to address it in the UI and
    // so its stages can be marked achieved before the server has ever seen it.
    // The server preserves ids the client sends, so this one survives the push.
    final stamped = _minted(goal);
    await _db.insert(_goals, stamped.toRow(userId, synced: false), conflictAlgorithm: .replace);
    return stamped;
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    final stamped = _minted(goal).copyWith(id: goalId);
    await _db.update(
      _goals,
      stamped.toRow(userId, synced: false),
      where: 'id = ? AND user_id = ?',
      whereArgs: [goalId, userId],
    );
    return stamped;
  }

  @override
  Future<void> deleteGoal(String goalId, String userId) {
    // A hard delete, with no tombstone: if the server delete then fails, the
    // goal comes back on the next reconcile. That is the honest outcome — the
    // server is the record for anything it has already confirmed.
    return _db.delete(_goals, where: 'id = ? AND user_id = ?', whereArgs: [goalId, userId]);
  }

  @override
  Future<Goal> markStageAchieved(String goalId, String stageId, String userId, DateTime achievedAt) async {
    final goal = await _findGoal(goalId, userId);
    if (goal == null) throw ArgumentError.value(goalId, 'goalId', 'no such goal');

    if (!goal.stages.any((stage) => stage.id == stageId)) {
      throw ArgumentError.value(stageId, 'stageId', 'no such stage on this goal');
    }

    final stages = goal.stages
        .map(
          (stage) => switch (stage.id) {
            final id when id == stageId => stage.copyWith(achievedAt: achievedAt),
            _ => stage,
          },
        )
        .toList();

    final updated = goal.copyWith(stages: stages);
    await _db.update(
      _goals,
      updated.toRow(userId, synced: false),
      where: 'id = ? AND user_id = ?',
      whereArgs: [goalId, userId],
    );
    return updated;
  }

  /// Replaces the server's view of this user's goals, marking every row synced.
  ///
  /// Unsynced local rows are left alone — they are writes the server has not
  /// accepted yet, and dropping them would lose work done offline.
  Future<void> storeGoals(Iterable<Goal> goals, String userId) {
    return _db.transaction(
      (txn) async {
        await txn.delete(_goals, where: 'user_id = ? AND synced = 1', whereArgs: [userId]);
        final batch = txn.batch();
        for (final goal in goals) {
          batch.insert(_goals, goal.toRow(userId, synced: true), conflictAlgorithm: .replace);
        }
        await batch.commit(noResult: true);
      },
    );
  }

  /// Goals written locally that the server has not confirmed, oldest first.
  Future<Iterable<Goal>> unsyncedGoals(String userId) {
    return _db
        .query(_goals, where: 'user_id = ? AND synced = 0', whereArgs: [userId], orderBy: 'created_at')
        .then((rows) => rows.map(Goal.fromRow));
  }

  /// Rewrites a local row under the id the server assigned it, and marks it
  /// synced. A no-op when the server kept the id we sent.
  Future<void> reconcileGoalId(String localId, Goal saved, String userId) {
    return _db.transaction(
      (txn) async {
        if (localId != saved.id) {
          await txn.delete(_goals, where: 'id = ? AND user_id = ?', whereArgs: [localId, userId]);
        }
        await txn.insert(_goals, saved.toRow(userId, synced: true), conflictAlgorithm: .replace);
      },
    );
  }

  Future<Goal?> _findGoal(String goalId, String userId) {
    return _db
        .query(
          _goals,
          where: 'id = ? AND user_id = ?',
          whereArgs: [goalId, userId],
          limit: 1,
        )
        .then((rows) => rows.isEmpty ? null : Goal.fromRow(rows.first));
  }

  /// Gives the goal and every stage an id if it hasn't got one.
  Goal _minted(Goal goal) {
    return goal.copyWith(
      id: goal.id ?? uuidV7(),
      stages: goal.stages.map((stage) => stage.id == null ? stage.copyWith(id: uuidV7()) : stage).toList(),
    );
  }
}

extension on Goal {
  Map<String, Object?> toRow(String userId, {required bool synced}) {
    return {
      'id': id,
      'user_id': userId,
      'metric': metric.value,
      'exercise_id': exerciseId,
      'cadence': cadence?.value,
      'stages': jsonEncode(stages.map((stage) => stage.toMap()).toList()),
      'archived': archived ? 1 : 0,
      'created_at': (createdAt ?? DateTime.timestamp()).toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }
}
