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
    user_id          TEXT
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
    workout_exercises.exercise_order,
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
    NULL AS exercise_order,
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

const getWorkout = """
WITH _workout AS (
    SELECT *
    FROM workouts
    WHERE id = ?
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
    workout_exercises.exercise_order,
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
    NULL AS exercise_order,
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
    workout_exercises.exercise_order,
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
    rest_timer    INTEGER,
    PRIMARY KEY (exercise_name, user_id)
);
""";

const getExerciseHistory = """
SELECT
   we.id AS exercise_id,
   workouts.id AS workout_id,
   workouts.name AS workout_name,
   sets.weight,
   sets.reps,
   sets.duration,
   sets.completed,
   sets.id AS set_id,
   sets.distance
FROM workout_exercises we
INNER JOIN workouts ON we.workout_id = workouts.id
INNER JOIN sets ON we.id = sets.exercise_id
WHERE we.exercise_id = ?
  AND workouts.user_id = ?
  AND sets.completed
;
""";

const weightRecord = """
SELECT
    max(reps) AS reps,
    max(weight) AS weight
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed;
""";

const distanceRecord = """
SELECT
    max(duration) AS duration,
    max(distance) AS distance
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed;
""";

const durationRecord = """
SELECT
    max(duration) AS duration
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed;
""";

const repsRecord = """
SELECT
    max(reps) AS reps
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed;
""";

const getWeightHistory = """
SELECT
    MAX(sets.weight) AS "value",
    sets.id AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
GROUP BY sets.id
ORDER BY "when" DESC
LIMIT ?
;
""";

const getRepsHistory = """
SELECT
    MAX(sets.reps) AS "value",
    sets.id AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
GROUP BY sets.id 
ORDER BY "when" DESC
LIMIT ?
;
""";

const getDurationHistory = """
SELECT
    MAX(sets.duration) AS "value",
    sets.id AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
GROUP BY sets.id 
ORDER BY "when" DESC
LIMIT ?
;
""";

const getDistanceHistory = """
SELECT
    MAX(sets.distance) AS "value",
    sets.id AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
GROUP BY sets.id
ORDER BY "when" DESC
LIMIT ?
;
""";

const getPreviousExercises = """
WITH _recent AS (
    SELECT
        we.exercise_id,
        we.workout_id,
        we.id AS workout_exercise_id,
        w.start AS last_workout_date
    FROM workout_exercises we
    JOIN sets s ON s.exercise_id = we.id
    JOIN workouts w ON w.id = we.workout_id
    WHERE s.completed = 1
      AND w.user_id = ?
    GROUP BY we.exercise_id
    HAVING MAX(w.start)
)
SELECT
    _recent.exercise_id AS "exerciseId",
    _recent.workout_exercise_id,
    _recent.last_workout_date,
    json_group_array(
        json_object(
            'set_id', s.id,
            'weight', s.weight,
            'reps', s.reps,
            'duration', s.duration,
            'distance', s.distance
        )
    ) AS sets
FROM _recent
JOIN sets s ON s.exercise_id = _recent.workout_exercise_id
WHERE s.completed = 1
GROUP BY _recent.exercise_id, _recent.workout_exercise_id, _recent.last_workout_date
;
""";
