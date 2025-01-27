const workouts = """
CREATE TABLE IF NOT EXISTS workouts
(
    id      TEXT NOT NULL PRIMARY KEY,
    start   TEXT NOT NULL,
    "end"   TEXT,
    name    TEXT
);
""";

const exercises = """
CREATE TABLE IF NOT EXISTS exercises
(
    exercise     TEXT NOT NULL PRIMARY KEY,
    joint        TEXT NOT NULL,
    level        TEXT NOT NULL,
    modality     TEXT NOT NULL,
    muscle_group TEXT NOT NULL,
    direction    TEXT NOT NULL,
    ulc          TEXT NOT NULL
);
""";

const syncs = """
CREATE TABLE IF NOT EXISTS syncs
(
    table_name TEXT NOT NULL PRIMARY KEY,
    synced_at  TEXT DEFAULT (datetime('now') || '+00:00')
);
""";

const sets = """
CREATE TABLE IF NOT EXISTS sets
(
    workout_id  TEXT    NOT NULL REFERENCES workouts (id),
    exercise_id TEXT    NOT NULL REFERENCES exercises (exercise),
    id          TEXT    NOT NULL PRIMARY KEY,
    completed   INTEGER NOT NULL DEFAULT 0,
    weight      REAL,
    reps        INT,
    duration    REAL
);
""";
