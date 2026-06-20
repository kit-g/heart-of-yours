part of '../../heart_db.dart';

const workouts = """
CREATE TABLE IF NOT EXISTS workouts
(
    id      TEXT NOT NULL PRIMARY KEY,
    start   TEXT NOT NULL,
    "end"   TEXT,
    user_id TEXT NOT NULL,
    name    TEXT,
    images  TEXT
);
""";

const exercises = """
CREATE TABLE IF NOT EXISTS exercises
(
    name             TEXT NOT NULL PRIMARY KEY,
    category         TEXT NOT NULL,
    target           TEXT NOT NULL,
    asset            TEXT,
    asset_width      INT,
    asset_height     INT,
    thumbnail        TEXT,
    thumbnail_width  INT,
    thumbnail_height INT,
    instructions     TEXT,
    user_id          TEXT,
    muscles          TEXT,
    own              INT  NOT NULL DEFAULT 0,
    archived         INT  NOT NULL DEFAULT 0,
    CHECK (own IN (0, 1)),
    CHECK (archived IN (0, 1)),
    CHECK (own = 1 OR user_id IS NULL),
    CHECK (length(name) > 0),
    CHECK (asset_width IS NULL OR asset_width > 0),
    CHECK (asset_height IS NULL OR asset_height > 0),
    CHECK (thumbnail_width IS NULL OR thumbnail_width > 0),
    CHECK (thumbnail_height IS NULL OR thumbnail_height > 0)
);
""";

const syncs = """
CREATE TABLE IF NOT EXISTS syncs
(
    table_name TEXT NOT NULL PRIMARY KEY,
    synced_at  TEXT DEFAULT (datetime('now') || '+00:00')
);
""";

const workoutExercises = """
CREATE TABLE IF NOT EXISTS workout_exercises
(
    workout_id     TEXT NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
    exercise_id    TEXT NOT NULL REFERENCES exercises (name) ON DELETE CASCADE,
    id             TEXT NOT NULL PRIMARY KEY,
    exercise_order INT
);
""";

const workoutExerciseIndex1 = """
CREATE INDEX IF NOT EXISTS exercise_idx ON workout_exercises (exercise_id);
""";

const workoutExerciseIndex2 = """
CREATE INDEX IF NOT EXISTS workout_idx ON workout_exercises (workout_id);
""";

const sets = """
CREATE TABLE IF NOT EXISTS sets
(
    exercise_id TEXT    NOT NULL REFERENCES workout_exercises (id) ON DELETE CASCADE,
    id          TEXT    NOT NULL PRIMARY KEY,
    completed   INTEGER NOT NULL DEFAULT 0,
    weight      REAL, -- kgs
    reps        INT,
    duration    REAL, -- seconds
    distance    REAL, -- kilometers,
    CHECK (weight >= 0),
    CHECK (reps >= 0),
    CHECK (duration >= 0),
    CHECK (distance >= 0)
);
""";

const setsIndex = """
CREATE INDEX IF NOT EXISTS exercise_idx ON sets (exercise_id);
""";

const templates = """
CREATE TABLE IF NOT EXISTS templates
(
    id              TEXT NOT NULL PRIMARY KEY,
    name            TEXT,
    user_id         TEXT,
    order_in_parent INTEGER,
    created_at      TEXT NOT NULL DEFAULT (datetime('now') || '+00:00')
);
""";

const templatesExercises = """
CREATE TABLE IF NOT EXISTS template_exercises
(
    id          TEXT    NOT NULL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES templates ON DELETE CASCADE,
    exercise_id TEXT    NOT NULL REFERENCES exercises ON DELETE CASCADE,
    description TEXT
);
""";

const templatesExercisesIndex1 = """
CREATE INDEX IF NOT EXISTS exercise_idx ON template_exercises (exercise_id);
""";

const templatesExercisesIndex2 = """
CREATE INDEX IF NOT EXISTS template_idx ON template_exercises (template_id);
""";

const charts = """
CREATE TABLE IF NOT EXISTS charts
(
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    type    TEXT NOT NULL,
    data    TEXT 
);
""";

const chartsIndex1 = """
CREATE INDEX IF NOT EXISTS user_idx ON charts (user_id);
""";

const exerciseDetails = """
CREATE TABLE IF NOT EXISTS exercise_details
(
    exercise_name TEXT NOT NULL REFERENCES exercises ON DELETE CASCADE,
    user_id       TEXT NOT NULL,
    rest_timer    INTEGER,
    PRIMARY KEY (exercise_name, user_id)
);
""";

const detailsIndex = """
CREATE INDEX IF NOT EXISTS exercise_name_idx ON exercise_details (exercise_name);
""";
