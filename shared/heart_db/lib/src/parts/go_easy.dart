part of '../../heart_db.dart';

/// The areas and movements a user goes easy on (heart-of-yours#396), on this
/// device only.
mixin _GoEasy on _LocalDatabase {
  Future<Set<String>> getGoEasy(String userId) async {
    final rows = await _db.query(_goEasy, columns: ['key'], where: 'user_id = ?', whereArgs: [userId]);
    return {
      for (final row in rows)
        if (row['key'] case final String key) key,
    };
  }

  /// Makes [keys] the whole list for [userId].
  Future<void> storeGoEasy(String userId, Set<String> keys) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch()..delete(_goEasy, where: 'user_id = ?', whereArgs: [userId]);
        for (final key in keys) {
          batch.insert(_goEasy, {'user_id': userId, 'key': key});
        }
        await batch.commit(noResult: true);
      },
    );
  }
}
