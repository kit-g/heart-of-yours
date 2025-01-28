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

const workoutExercises = """
CREATE TABLE IF NOT EXISTS workout_exercises
(
    workout_id     TEXT NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
    exercise_id    TEXT NOT NULL REFERENCES exercises (exercise) ON DELETE CASCADE,
    id             TEXT NOT NULL PRIMARY KEY,
    exercise_order INT
);
""";

const sets = """
CREATE TABLE IF NOT EXISTS sets
(
    exercise_id TEXT    NOT NULL REFERENCES workout_exercises (id) ON DELETE CASCADE,
    id          TEXT    NOT NULL PRIMARY KEY,
    completed   INTEGER NOT NULL DEFAULT 0,
    weight      REAL,
    reps        INT,
    duration    REAL
);
""";


const activeWorkout = """
WITH _workout AS (
    SELECT *
    FROM workouts
    WHERE "end" IS NULL
    ORDER BY start DESC
    LIMIT 1
)
SELECT
    _workout.id AS workout_id,
    _workout.start,
    _workout."end",
    _workout.name,
    workout_exercises.id as workout_exercise_id,
    sets.id AS set_id,
    sets.completed,
    sets.weight,
    sets.reps,
    sets.duration,
    exercise,
    joint,
    level,
    modality,
    muscle_group,
    direction,
    ulc
FROM workout_exercises
INNER JOIN _workout
    ON _workout.id = workout_exercises.workout_id
INNER JOIN sets
    ON workout_exercises.id = sets.exercise_id
INNER JOIN exercises e
    ON e.exercise = workout_exercises.exercise_id

UNION ALL

SELECT
    _workout.id AS workout_id,
    _workout.start,
    _workout."end",
    _workout.name,
    NULL AS workout_exercise_id,
    NULL AS set_id,
    NULL AS completed,
    NULL AS weight,
    NULL AS reps,
    NULL AS duration,
    NULL AS exercise,
    NULL AS joint,
    NULL AS level,
    NULL AS modality,
    NULL AS muscle_group,
    NULL AS direction,
    NULL AS ulc
FROM _workout
WHERE NOT exists (
    SELECT 1
    FROM workout_exercises
    INNER JOIN sets
        ON workout_exercises.id = sets.exercise_id
    INNER JOIN exercises e
        ON e.exercise = workout_exercises.exercise_id
    WHERE workout_exercises.workout_id = _workout.id
);
""";