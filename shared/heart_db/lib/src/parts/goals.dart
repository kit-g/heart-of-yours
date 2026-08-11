part of '../../heart_db.dart';

/// The local mirror of the user's goals.
///
/// Implements the same [GoalService] the remote API does, so [Goals] in
/// `heart_state` can hold one of each and write locally first — the pattern
/// workouts already use. Rows carry a `synced` flag; anything still 0 is a
/// write the server has not confirmed.
mixin _Goals on _LocalDatabase implements GoalService {
  /// The local mirror only ever holds the signed-in user's goals, so there is
  /// nobody else's to read: [requesterId] is accepted to satisfy the shared
  /// interface and asserted against [targetUserId] rather than silently
  /// answering with the wrong person's ladder.
  ///
  /// [archived] picks a slice and never a union, matching the server: false is
  /// the live list, true the achieved surface behind the card flip.
  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) {
    assert(requesterId == targetUserId, 'the local mirror holds only the signed-in user\'s goals');
    return _db
        .query(
          _goals,
          where: 'user_id = ? AND archived = ?',
          whereArgs: [targetUserId, archived ? 1 : 0],
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
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    final goal = await _findGoal(goalId, userId);
    if (goal == null) throw ArgumentError.value(goalId, 'goalId', 'no such goal');

    if (!goal.stages.any((stage) => stage.id == stageId)) {
      throw ArgumentError.value(stageId, 'stageId', 'no such stage on this goal');
    }

    final stages = goal.stages
        .map(
          (stage) => switch (stage.id) {
            final id when id == stageId => stage.copyWith(achievedAt: achievedAt, achievedBy: achievedBy),
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

  /// Replaces the server's view of one slice of this user's goals, marking
  /// every row synced.
  ///
  /// Unsynced local rows are left alone — they are writes the server has not
  /// accepted yet, and dropping them would lose work done offline.
  Future<void> storeGoals(Iterable<Goal> goals, String userId, {bool archived = false}) {
    return _db.transaction(
      (txn) async {
        // Only the slice being replaced. The live list and the achieved surface
        // are pulled separately, so clearing both here would mean whichever
        // landed second wiped the other.
        await txn.delete(
          _goals,
          where: 'user_id = ? AND synced = 1 AND archived = ?',
          whereArgs: [userId, archived ? 1 : 0],
        );
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
