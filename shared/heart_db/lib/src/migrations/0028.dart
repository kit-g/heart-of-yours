part of '../../heart_db.dart';

/// Suspicious entries (#428, heart-api#42): what the server's sweep found odd
/// in the log, a set or a workout's duration, and what the user made of it.
///
/// A mirror of `GET /anomalies`, plus `synced`: a decision taken on this
/// device stays 0 until the server has it. The set and the workout are links,
/// never requirements, as on the server: no foreign key, so a set deleted
/// under its anomaly leaves a row nothing reads. `observed` is JSON, as on the
/// wire. Kept whatever the feature's switch says (`docs/opt-in.md`).
const createAnomalies = '''
CREATE TABLE IF NOT EXISTS anomalies
(
    id            TEXT    NOT NULL PRIMARY KEY,
    user_id       TEXT    NOT NULL,
    workout_id    TEXT    NOT NULL,
    workout_start TEXT,
    set_id        TEXT,
    exercise_id   TEXT,
    exercise_name TEXT,
    reason        TEXT    NOT NULL,
    observed      TEXT    NOT NULL,
    typical       REAL,
    status        TEXT    NOT NULL,
    detected_at   TEXT    NOT NULL,
    resolved_at   TEXT,
    synced        INTEGER NOT NULL DEFAULT 1
);
''';

/// The counts ask about one set or one workout at a time.
const anomaliesSetIndex = 'CREATE INDEX IF NOT EXISTS anomalies_set_idx ON anomalies (set_id);';
const anomaliesWorkoutIndex = 'CREATE INDEX IF NOT EXISTS anomalies_workout_idx ON anomalies (user_id, workout_id);';
