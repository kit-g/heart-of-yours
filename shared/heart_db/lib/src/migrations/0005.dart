part of '../../heart_db.dart';

/// v5: movement pattern and load attributes, mirroring `muscles` — a JSON blob
/// on the shared catalog row rather than columns, because the vocabulary is
/// owned by content and can grow without an app release.
///
/// Not merely additive: `storeExercises` builds its insert generically from
/// `Exercise.toMap()`, which emits `movement` for every annotated exercise, so
/// without this column the catalog write fails outright.
const addExerciseMovement = '''
ALTER TABLE exercises ADD COLUMN movement TEXT;
''';
