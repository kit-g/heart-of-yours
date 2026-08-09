part of '../../heart_db.dart';

/// v1 meant to index `sets (exercise_id)` but reused the name `exercise_idx`,
/// already claimed by `workout_exercises` — index names are database-global, so
/// `IF NOT EXISTS` silently skipped it and exercise-history lookups have been
/// scanning the whole table. The misnamed constant stays in 0001 because
/// migrations are immutable history; this one creates the index under a name of
/// its own.
const addSetsExerciseIndex = '''
CREATE INDEX IF NOT EXISTS sets_exercise_idx ON sets (exercise_id);
''';

/// In a SQLite UNIQUE index NULLs compare distinct, so `charts_unique_idx`
/// never fired for rows with NULL `data` and account-wide charts could
/// duplicate on every re-save. Rebuild it over `ifnull(data, '')`, deduping
/// first (GROUP BY does treat NULLs as equal, same policy as v4: keep the
/// earliest row).
const dropChartsUniqueIndex = '''
DROP INDEX IF EXISTS charts_unique_idx;
''';

const dedupeNullDataChartPreferences = '''
DELETE FROM charts
WHERE id NOT IN (
    SELECT min(id)
    FROM charts
    GROUP BY user_id, type, data
);
''';

const chartsUniqueIndexNullSafe = """
CREATE UNIQUE INDEX IF NOT EXISTS charts_unique_idx ON charts (user_id, type, ifnull(data, ''));
""";
