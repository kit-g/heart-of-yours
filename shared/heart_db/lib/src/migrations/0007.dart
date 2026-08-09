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
const goals = '''
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
);
''';

/// Every read is "this user's live goals", matching the server's partial index.
const goalsIndex = '''
CREATE INDEX IF NOT EXISTS goals_user_idx ON goals (user_id) WHERE archived = 0;
''';
