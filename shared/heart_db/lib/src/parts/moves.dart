part of '../../heart_db.dart';

/// Moving an exercise's history onto another exercise (heart-of-yours#338),
/// as the server did it (heart-api#140): the mirror's copy of the move the
/// account has already made.
mixin _Moves on _LocalDatabase {
  /// Re-keys everything [userId] holds under [sourceId] onto [targetId], in
  /// one transaction, so the device reads as if the target had been used all
  /// along.
  ///
  /// The server's rules, row for row:
  /// - logged exercises and template entries are re-keyed in place, so a
  ///   workout or template that held both exercises holds the target twice;
  /// - the per-exercise preference row (rest timer, unit, pinned note) is
  ///   re-keyed, unless the target already has one, which is then kept whole
  ///   and the source's dropped;
  /// - goals are re-keyed, and a goal on each side stays two goals.
  ///
  /// Chart preferences are the device's own (the server keeps its chart
  /// settings on the preference row) and follow the same rule as the
  /// preference: the target's chart of a type wins over the source's.
  ///
  /// [deleteSource] removes the source from the user's own exercises, as the
  /// server does for a custom: it is the server's answer, never decided here.
  /// Only the children above are re-keyed first, so the cascade has nothing
  /// left to take with it.
  Future<void> moveExerciseHistory({
    required String sourceId,
    required String targetId,
    required String userId,
    required bool deleteSource,
  }) {
    return _db.transaction(
      (txn) async {
        await txn.rawUpdate(
          '''
          UPDATE $_workoutExercises SET exercise_id = ?
          WHERE exercise_id = ?
            AND workout_id IN (SELECT id FROM $_workouts WHERE user_id = ?)
          ''',
          [targetId, sourceId, userId],
        );
        await txn.rawUpdate(
          '''
          UPDATE $_templatesExercises SET exercise_id = ?
          WHERE exercise_id = ?
            AND template_id IN (SELECT id FROM $_templates WHERE user_id = ?)
          ''',
          [targetId, sourceId, userId],
        );

        // the target's row, when there is one, is kept whole
        await txn.rawUpdate(
          'UPDATE OR IGNORE $_exerciseDetails SET exercise_id = ? WHERE exercise_id = ? AND user_id = ?',
          [targetId, sourceId, userId],
        );
        await txn.delete(_exerciseDetails, where: 'exercise_id = ? AND user_id = ?', whereArgs: [sourceId, userId]);

        await txn.update(
          _goals,
          {'exercise_id': targetId},
          where: 'exercise_id = ? AND user_id = ?',
          whereArgs: [sourceId, userId],
        );

        // a program's rule and bases follow the exercise (#346)
        final batch = txn.batch();
        _Programs._rekeyExercise(batch, userId, from: sourceId, to: targetId);
        await batch.commit(noResult: true);
        await _Programs._rekeyRules(txn, userId, from: sourceId, to: targetId);

        // a chart the target already has, of the same type, wins
        await txn.rawUpdate(
          '''
          UPDATE OR IGNORE $_charts SET data = json_set(data, '\$.exerciseName', ?)
          WHERE user_id = ? AND json_extract(data, '\$.exerciseName') = ?
          ''',
          [targetId, userId, sourceId],
        );
        await txn.rawDelete(
          "DELETE FROM $_charts WHERE user_id = ? AND json_extract(data, '\$.exerciseName') = ?",
          [userId, sourceId],
        );

        if (deleteSource) {
          await txn.delete(_exercises, where: 'id = ? AND user_id = ?', whereArgs: [sourceId, userId]);
        }
      },
    );
  }
}
