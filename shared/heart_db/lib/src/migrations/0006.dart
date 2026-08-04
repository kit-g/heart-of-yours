part of '../../heart_db.dart';

/// v7: goals — the local mirror of the server's goal definitions.
///
/// Shape follows the server table (`goals` in heart-go) with three deliberate
/// differences, all of them SQLite's doing:
/// - `id` is TEXT and client-minted. A goal written offline needs a key before
///   the server has seen it; on the first successful push the server's id wins
///   and the local row is rewritten under it.
/// - `archived` is INTEGER, since SQLite has no boolean. `Goal.fromRow` accepts
///   both that and Postgres' real bool, so rows go straight through it.
/// - `stages` is TEXT holding the same JSON array the wire carries, so the blob
///   round-trips through `Goal.fromRow` unchanged.
const goals = """
CREATE TABLE IF NOT EXISTS goals
(
    id          TEXT PRIMARY KEY,
    user_id     TEXT    NOT NULL,
    metric      TEXT    NOT NULL,
    exercise_id TEXT,
    cadence     TEXT,
    stages      TEXT    NOT NULL,
    archived    INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT,
    synced      INTEGER NOT NULL DEFAULT 0
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
""";

const chartsUniqueIndexNullSafe = """
CREATE UNIQUE INDEX IF NOT EXISTS charts_unique_idx ON charts (user_id, type, ifnull(data, ''));
/// Every read is "this user's live goals", matching the server's partial index.
const goalsIndex = """
CREATE INDEX IF NOT EXISTS goals_user_idx ON goals (user_id) WHERE archived = 0;
""";
