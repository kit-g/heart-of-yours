part of '../../heart_db.dart';

/// v10: how each exercise is represented in the platform health store, mirroring
/// `movement` — a JSON blob on the shared catalog row rather than a column,
/// because the vocabulary is owned by content and can grow without an app
/// release.
///
/// Not merely additive, for the same reason v5 was not: `storeExercises` builds
/// its insert generically from `Exercise.toMap()`, which emits `health` for
/// every annotated exercise, so without this column the catalog write fails
/// outright.
///
/// Null for most rows and for every user-created exercise. That is not missing
/// data — `Exercise.activity` falls back to the category, so an unannotated
/// exercise still resolves. See `docs/2026-08-02.wearables.md` §"Tier 1".
const addExerciseHealth = '''
ALTER TABLE exercises ADD COLUMN health TEXT;
''';
