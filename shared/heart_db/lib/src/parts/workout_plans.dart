part of '../../heart_db.dart';

/// What a program workout was asked to be (#566, #558): stored when the
/// workout starts, sent once the workout is on the server.
mixin _WorkoutPlans on _LocalDatabase {
  /// Keeps [plan] for [workoutId]. A second plan for the same workout replaces
  /// the first only while neither has reached the server, since the server
  /// keeps the first it gets.
  Future<void> storeWorkoutPlan(String workoutId, String userId, Map<String, dynamic> plan) {
    return _db.rawInsert(
      '''
      INSERT INTO $_workoutPlans (workout_id, user_id, plan, synced) VALUES (?, ?, ?, 0)
      ON CONFLICT (workout_id) DO UPDATE SET plan = excluded.plan WHERE synced = 0
      ''',
      [workoutId, userId, jsonEncode(plan)],
    );
  }

  /// [userId]'s plans the server hasn't taken, for workouts it already has: a
  /// plan for a workout still in progress, or not yet saved, would be refused.
  Future<List<({String workoutId, Map<String, dynamic> plan})>> getUnsentWorkoutPlans(String userId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT p.workout_id, p.plan
      FROM $_workoutPlans p
      JOIN $_workouts w ON w.id = p.workout_id
      WHERE p.user_id = ? AND p.synced = 0 AND w.synced = 1
      ORDER BY p.workout_id
      ''',
      [userId],
    );
    return [
      for (final row in rows)
        if (row case {'workout_id': final String workoutId, 'plan': final String plan})
          if (jsonDecode(plan) case final Map<String, dynamic> decoded) (workoutId: workoutId, plan: decoded),
    ];
  }

  Future<void> markWorkoutPlanSent(String workoutId) {
    return _db.update(_workoutPlans, {'synced': 1}, where: 'workout_id = ?', whereArgs: [workoutId]);
  }

  /// The plan stored for [workoutId], sent or not.
  Future<Map<String, dynamic>?> getWorkoutPlan(String workoutId) async {
    final rows = await _db.query(_workoutPlans, columns: ['plan'], where: 'workout_id = ?', whereArgs: [workoutId]);
    return switch (rows) {
      [{'plan': final String plan}] => jsonDecode(plan) as Map<String, dynamic>,
      _ => null,
    };
  }
}
