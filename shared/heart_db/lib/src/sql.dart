const workouts = """
CREATE TABLE IF NOT EXISTS workouts
(
    id      TEXT NOT NULL PRIMARY KEY,
    start   TEXT NOT NULL,
    "end"   TEXT,
    user_id TEXT NOT NULL,
    name    TEXT
);
""";

const exercises = """
CREATE TABLE IF NOT EXISTS exercises
(
    name         TEXT NOT NULL PRIMARY KEY,
    category     TEXT NOT NULL,
    target       TEXT NOT NULL,
    user_id      TEXT
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

const sets = """
CREATE TABLE IF NOT EXISTS sets
(
    exercise_id TEXT    NOT NULL REFERENCES workout_exercises (id) ON DELETE CASCADE,
    id          TEXT    NOT NULL PRIMARY KEY,
    completed   INTEGER NOT NULL DEFAULT 0,
    weight      REAL,  -- kgs
    reps        INT,
    duration    REAL,  -- seconds
    distance    REAL   -- kilometers
);
""";

const templates = """
CREATE TABLE IF NOT EXISTS templates
(
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT,
    user_id         TEXT,
    order_in_parent INTEGER,
    created_at      TEXT NOT NULL DEFAULT (datetime('now') || '+00:00')
);
""";

const templatesExercises = """
CREATE TABLE IF NOT EXISTS template_exercises
(
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL REFERENCES templates ON DELETE CASCADE,
    exercise_id TEXT    NOT NULL REFERENCES exercises ON DELETE CASCADE,
    description TEXT
);
""";

const activeWorkout = """
WITH _workout AS (
    SELECT *
    FROM workouts
    WHERE "end" IS NULL
      AND user_id = ?
    ORDER BY start DESC
    LIMIT 1
)
SELECT
    _workout.id AS workout_id,
    _workout.start,
    _workout."end",
    _workout.name AS workout_name,
    workout_exercises.id as workout_exercise_id,
    sets.id AS set_id,
    sets.completed,
    sets.weight,
    sets.reps,
    sets.duration,
    sets.distance,
    e.name,
    target,
    category
FROM workout_exercises
INNER JOIN _workout
    ON _workout.id = workout_exercises.workout_id
INNER JOIN sets
    ON workout_exercises.id = sets.exercise_id
INNER JOIN exercises e
    ON e.name = workout_exercises.exercise_id

UNION ALL

SELECT
    _workout.id AS workout_id,
    _workout.start,
    _workout."end",
    _workout.name AS workout_name,
    NULL AS workout_exercise_id,
    NULL AS set_id,
    NULL AS completed,
    NULL AS weight,
    NULL AS reps,
    NULL AS duration,
    NULL AS distance,
    NULL AS name,
    NULL AS category,
    NULL AS target
FROM _workout
WHERE NOT exists (
    SELECT 1
    FROM workout_exercises
    INNER JOIN sets
        ON workout_exercises.id = sets.exercise_id
    INNER JOIN exercises e
        ON e.name = workout_exercises.exercise_id
    WHERE workout_exercises.workout_id = _workout.id
);
""";

const history = """
WITH _workout AS (
    SELECT *
    FROM workouts
    WHERE "end" IS NOT NULL
      AND user_id = ?
)
SELECT
    _workout.id AS workout_id,
    _workout.start,
    _workout."end",
    _workout.name AS workout_name,
    workout_exercises.id as workout_exercise_id,
    sets.id AS set_id,
    sets.completed,
    sets.weight,
    sets.reps,
    sets.duration,
    sets.distance,
    e.name,
    target,
    category
FROM workout_exercises
INNER JOIN _workout
    ON _workout.id = workout_exercises.workout_id
INNER JOIN sets
    ON workout_exercises.id = sets.exercise_id
INNER JOIN exercises e
    ON e.name = workout_exercises.exercise_id
    ;
""";

const removeUnfinished = """
DELETE
FROM sets
WHERE completed = 0
  AND exercise_id IN (
          SELECT id
          FROM workout_exercises
          WHERE workout_id = ?
      );
""";

const getTemplates = """
SELECT 
    templates.name as template_name,
    order_in_parent,
    created_at,
    te.id ,
    template_id,
    description,
    e.name,
    category,
    target
FROM templates
INNER JOIN main.template_exercises te
    ON templates.id = te.template_id
INNER JOIN main.exercises e
    ON te.exercise_id = e.name
WHERE templates.user_id = ?
;
""";

const getSampleTemplates = """
SELECT 
    templates.name as template_name,
    order_in_parent,
    created_at,
    te.id ,
    template_id,
    description,
    e.name,
    category,
    target
FROM templates
INNER JOIN main.template_exercises te
    ON templates.id = te.template_id
INNER JOIN main.exercises e
    ON te.exercise_id = e.name
WHERE templates.user_id IS NULL
;
""";

const exerciseDetails = """
CREATE TABLE IF NOT EXISTS exercise_details
(
    exercise_name TEXT NOT NULL REFERENCES exercises ON DELETE CASCADE,
    user_id       TEXT NOT NULL,
    last_done     TEXT,
    last_results  TEXT,
    rest_timer    INTEGER,
    PRIMARY KEY (exercise_name, user_id)
);
""";