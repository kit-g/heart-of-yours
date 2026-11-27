part of '../../heart_db.dart';

/// Suspicious entries (#428, heart-api#42): the server's flags on the log, and
/// the user's decisions on them. The counts read the decisions through
/// [_LocalDatabase.leavesOutDiscarded]; this is where they are kept.
mixin _Anomalies on _LocalDatabase {
  /// [userId]'s anomalies, newest found first, as the server lists them.
  Future<List<Anomaly>> getAnomalies(String userId) async {
    final rows = await _db.query(
      _anomalies,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'detected_at DESC, id',
    );
    return _readable(rows, _anomalyOf, what: 'anomaly');
  }

  /// Decisions taken on this device that the server has not confirmed.
  Future<List<Anomaly>> unsyncedAnomalies(String userId) async {
    final rows = await _db.query(_anomalies, where: 'user_id = ? AND synced = 0', whereArgs: [userId]);
    return _readable(rows, _anomalyOf, what: 'anomaly');
  }

  /// Replaces [userId]'s anomalies with [anomalies], a full read from the
  /// server, marking each synced.
  ///
  /// A decision this device took and has not pushed yet survives the read, as
  /// long as the anomaly is still the question it answered: one found again
  /// since (an edited set still odd) is a new question, and the server's
  /// pending row wins. One the server no longer has is gone, decision and all:
  /// its entry was edited out of being odd.
  Future<void> storeAnomalies(Iterable<Anomaly> anomalies, String userId) {
    return _db.transaction(
      (txn) async {
        final owed = {
          for (final row in await txn.query(_anomalies, where: 'user_id = ? AND synced = 0', whereArgs: [userId]))
            row['id']: row,
        };
        await txn.delete(_anomalies, where: 'user_id = ?', whereArgs: [userId]);
        for (final anomaly in anomalies) {
          final row = switch (owed[anomaly.id]) {
            {'detected_at': final String at, 'status': final String status, 'resolved_at': final String? resolved}
                when at == _instant(anomaly.detectedAt) =>
              {..._rowOf(anomaly, userId), 'status': status, 'resolved_at': resolved, 'synced': 0},
            _ => _rowOf(anomaly, userId),
          };
          await txn.insert(_anomalies, row, conflictAlgorithm: .replace);
        }
      },
    );
  }

  /// Records what the user made of [anomalyId], unsynced until the server
  /// confirms it with [storeAnomaly].
  Future<void> resolveAnomaly(String anomalyId, AnomalyStatus status, {required DateTime at}) {
    return _db.update(
      _anomalies,
      {'status': status.value, 'resolved_at': _instant(at), 'synced': 0},
      where: 'id = ?',
      whereArgs: [anomalyId],
    );
  }

  /// One anomaly as the server answered it, synced.
  Future<void> storeAnomaly(Anomaly anomaly, String userId) {
    return _db.insert(_anomalies, _rowOf(anomaly, userId), conflictAlgorithm: .replace);
  }

  static String _instant(DateTime at) => at.toUtc().toIso8601String();

  static Map<String, Object?> _rowOf(Anomaly anomaly, String userId) {
    return {
      'id': anomaly.id,
      'user_id': userId,
      'workout_id': anomaly.workoutId,
      'workout_start': switch (anomaly.workoutStart) {
        final DateTime start => _instant(start),
        null => null,
      },
      'set_id': anomaly.setId,
      'exercise_id': anomaly.exerciseId,
      'exercise_name': anomaly.exerciseName,
      'reason': anomaly.reason,
      'observed': jsonEncode(anomaly.observed),
      'typical': anomaly.typical,
      'status': anomaly.status.value,
      'detected_at': _instant(anomaly.detectedAt),
      'resolved_at': switch (anomaly.resolvedAt) {
        final DateTime resolved => _instant(resolved),
        null => null,
      },
      'synced': 1,
    };
  }

  static Anomaly _anomalyOf(Map<String, Object?> row) {
    return Anomaly.fromJson({
      'id': row['id'],
      'workoutId': row['workout_id'],
      'workoutStart': row['workout_start'],
      'setId': row['set_id'],
      'exerciseId': row['exercise_id'],
      'exerciseName': row['exercise_name'],
      'reason': row['reason'],
      'observed': jsonDecode(row['observed'] as String),
      'typical': row['typical'],
      'status': row['status'],
      'detectedAt': row['detected_at'],
      'resolvedAt': row['resolved_at'],
    });
  }
}
