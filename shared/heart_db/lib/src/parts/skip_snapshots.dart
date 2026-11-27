part of '../../heart_db.dart';

/// A skip's snapshot as its row holds it (#445): when it was taken, the
/// training before the skip, and what Health had for the day, by metric.
/// [body] is null once the health mirror was forgotten, or with nothing read.
typedef SkipSnapshotRow = ({DateTime takenAt, Map<String, Object?> training, Map<String, double>? body});

/// What a day looked like when it was set aside (heart-of-yours#445), on this
/// device only: nothing here has a remote counterpart, an export or a replay.
mixin _SkipSnapshots on _LocalDatabase {
  Future<SkipSnapshotRow?> getSkipSnapshot(String skipId) async {
    final rows = await _db.query(_skipSnapshots, where: 'skip_id = ?', whereArgs: [skipId], limit: 1);
    return switch (rows.firstOrNull) {
      final Map<String, Object?> row => _readOne(() => _snapshotOf(row), what: 'skip snapshot'),
      null => null,
    };
  }

  /// Keeps [snapshot] for [skipId], unless it has one: a snapshot is the
  /// moment of the skip, and a second look is not that moment.
  Future<void> storeSkipSnapshot(String skipId, String userId, SkipSnapshotRow snapshot) {
    return _db.insert(
      _skipSnapshots,
      {
        'skip_id': skipId,
        'user_id': userId,
        'taken_at': snapshot.takenAt.toUtc().toIso8601String(),
        'training': jsonEncode(snapshot.training),
        'body': switch (snapshot.body) {
          final Map<String, double> body when body.isNotEmpty => jsonEncode(body),
          _ => null,
        },
      },
      conflictAlgorithm: .ignore,
    );
  }

  Future<void> deleteSkipSnapshot(String skipId) {
    return _db.delete(_skipSnapshots, where: 'skip_id = ?', whereArgs: [skipId]);
  }

  /// Hands [from]'s snapshot to [to]: a reason given stores the same skip
  /// again under a new id (#312).
  Future<void> moveSkipSnapshot(String from, String to) {
    return _db.rawUpdate('UPDATE OR REPLACE $_skipSnapshots SET skip_id = ? WHERE skip_id = ?', [to, from]);
  }

  static SkipSnapshotRow _snapshotOf(Map<String, Object?> row) {
    return (
      takenAt: DateTime.parse(row['taken_at'] as String),
      training: (jsonDecode(row['training'] as String) as Map).cast<String, Object?>(),
      body: switch (row['body']) {
        final String body => {
          for (final MapEntry(:key, :value) in (jsonDecode(body) as Map).entries)
            if (value is num) '$key': value.toDouble(),
        },
        _ => null,
      },
    );
  }
}
