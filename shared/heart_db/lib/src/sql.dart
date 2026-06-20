const activeWorkout = """
WITH
  _workout AS (
    SELECT *
    FROM workouts
    WHERE "end" IS NULL
      AND user_id = ?
    ORDER BY start DESC
    LIMIT 1
)
, _ex AS (
    SELECT 
        workout_exercises.*,
        json_object(
            'id', exercises.id,
            'name', exercises.name,
            'category', exercises.category,
            'target', exercises.target,
            'asset', exercises.asset,
            'assetWidth', exercises.asset_width,
            'assetHeight', exercises.asset_height,
            'thumbnail', exercises.thumbnail,
            'thumbnailWidth', exercises.thumbnail_width,
            'thumbnailHeight', exercises.thumbnail_height,
            'instructions', exercises.instructions,
            'own', exercises.own,
            'archived', exercises.archived,
            'muscles', json(coalesce(exercises.muscles, '{}'))
        ) AS exercise_json
    FROM workout_exercises
    INNER JOIN _workout ON _workout.id = workout_exercises.workout_id
    INNER JOIN exercises ON exercises.name = workout_exercises.exercise_id
)
, _sets AS (
    SELECT *
    FROM sets
    WHERE exercise_id IN (SELECT id FROM _ex)
)
SELECT
    _workout.id AS id,
    _workout.start,
    _workout."end",
    _workout.name,
    _workout.images,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'order', _ex.exercise_order,
                'exercise', json(_ex.exercise_json),
                'sets', (
                    SELECT json_group_array(
                        json_object(
                            'id', _sets.id,
                            'weight', _sets.weight,
                            'reps', _sets.reps,
                            'duration', _sets.duration,
                            'distance', _sets.distance,
                            'completed', _sets.completed
                        )
                    )
                    FROM _sets
                    WHERE exercise_id = _ex.id
                )
            )
        )
        FROM _ex
        WHERE workout_id = _workout.id
    )
AS exercises
FROM _workout
;
""";

const getWorkout = """
WITH
  _workout AS (
    SELECT *
    FROM workouts
    WHERE id = ?
      AND user_id = ?
    ORDER BY start DESC
    LIMIT 1
)
, _ex AS (
    SELECT 
        workout_exercises.*,
        json_object(
            'id', exercises.id,
            'name', exercises.name,
            'category', exercises.category,
            'target', exercises.target,
            'asset', exercises.asset,
            'assetWidth', exercises.asset_width,
            'assetHeight', exercises.asset_height,
            'thumbnail', exercises.thumbnail,
            'thumbnailWidth', exercises.thumbnail_width,
            'thumbnailHeight', exercises.thumbnail_height,
            'instructions', exercises.instructions,
            'own', exercises.own,
            'archived', exercises.archived,
            'muscles', json(coalesce(exercises.muscles, '{}'))
        ) AS exercise_json
    FROM workout_exercises
    INNER JOIN _workout ON _workout.id = workout_exercises.workout_id
    INNER JOIN exercises ON exercises.name = workout_exercises.exercise_id
)
, _sets AS (
    SELECT *
    FROM sets
    WHERE exercise_id IN (SELECT id FROM _ex)
)
SELECT
    _workout.id AS id,
    _workout.start,
    _workout."end",
    _workout.name,
    _workout.images,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'order', _ex.exercise_order,
                'exercise', json(_ex.exercise_json),
                'sets', (
                    SELECT json_group_array(
                        json_object(
                            'id', _sets.id,
                            'weight', _sets.weight,
                            'reps', _sets.reps,
                            'duration', _sets.duration,
                            'distance', _sets.distance,
                            'completed', _sets.completed
                        )
                    )
                    FROM _sets
                    WHERE exercise_id = _ex.id
                )
            )
        )
        FROM _ex
        WHERE workout_id = _workout.id
    )
AS exercises
FROM _workout
;
""";

const history = """
WITH
  _workouts AS (
    SELECT *
    FROM workouts
    WHERE "end" IS NOT NULL
      AND user_id = ?
)
, _ex AS (
    SELECT 
        workout_exercises.*,
        json_object(
            'id', exercises.id,
            'name', exercises.name,
            'category', exercises.category,
            'target', exercises.target,
            'asset', exercises.asset,
            'assetWidth', exercises.asset_width,
            'assetHeight', exercises.asset_height,
            'thumbnail', exercises.thumbnail,
            'thumbnailWidth', exercises.thumbnail_width,
            'thumbnailHeight', exercises.thumbnail_height,
            'instructions', exercises.instructions,
            'own', exercises.own,
            'archived', exercises.archived,
            'muscles', json(coalesce(exercises.muscles, '{}'))
        ) AS exercise_json
    FROM workout_exercises
    INNER JOIN exercises ON exercises.name = workout_exercises.exercise_id
    WHERE workout_id IN (SELECT id FROM _workouts)
)
, _sets AS (
    SELECT *
    FROM sets
    WHERE exercise_id IN (SELECT id FROM _ex)
)
SELECT
    _workouts.id AS id,
    _workouts.start,
    _workouts."end",
    _workouts.name,
    _workouts.images,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'order', _ex.exercise_order,
                'exercise', json(_ex.exercise_json),
                'sets', (
                    SELECT json_group_array(
                        json_object(
                            'id', _sets.id,
                            'weight', _sets.weight,
                            'reps', _sets.reps,
                            'duration', _sets.duration,
                            'distance', _sets.distance,
                            'completed', _sets.completed
                        )
                    )
                    FROM _sets
                    WHERE exercise_id = _ex.id
                )
            )
        )
        FROM _ex
        WHERE workout_id = _workouts.id
        )
    AS exercises
FROM _workouts;
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
WITH
  _templates AS (
    SELECT *
    FROM templates
    WHERE user_id = ?
)
, _ex AS (
    SELECT 
        template_exercises.*,
        json_object(
            'id', exercises.id,
            'name', exercises.name,
            'category', exercises.category,
            'target', exercises.target,
            'asset', exercises.asset,
            'assetWidth', exercises.asset_width,
            'assetHeight', exercises.asset_height,
            'thumbnail', exercises.thumbnail,
            'thumbnailWidth', exercises.thumbnail_width,
            'thumbnailHeight', exercises.thumbnail_height,
            'instructions', exercises.instructions,
            'own', exercises.own,
            'archived', exercises.archived,
            'muscles', json(coalesce(exercises.muscles, '{}'))
        ) AS exercise_json
    FROM template_exercises
    INNER JOIN exercises ON exercises.name = template_exercises.exercise_id
    WHERE template_id IN (SELECT id FROM _templates)
)
SELECT
    id,
    name,
    order_in_parent AS "order",
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'sets', json(_ex.description),
                'exercise', json(_ex.exercise_json)
            )
        )
        FROM _ex
        WHERE _ex.template_id = _templates.id
    ) AS exercises
FROM _templates
;
""";

const getSampleTemplates = """
WITH
  _templates AS (
    SELECT *
    FROM templates
    WHERE user_id IS NULL
)
, _ex AS (
    SELECT 
        template_exercises.*,
        json_object(
            'id', exercises.id,
            'name', exercises.name,
            'category', exercises.category,
            'target', exercises.target,
            'asset', exercises.asset,
            'assetWidth', exercises.asset_width,
            'assetHeight', exercises.asset_height,
            'thumbnail', exercises.thumbnail,
            'thumbnailWidth', exercises.thumbnail_width,
            'thumbnailHeight', exercises.thumbnail_height,
            'instructions', exercises.instructions,
            'own', exercises.own,
            'archived', exercises.archived,
            'muscles', json(coalesce(exercises.muscles, '{}'))
        ) AS exercise_json
    FROM template_exercises
    INNER JOIN exercises ON exercises.name = template_exercises.exercise_id
    WHERE template_id IN (SELECT id FROM _templates)
)
SELECT
    id,
    name,
    order_in_parent AS "order",
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'sets', json(_ex.description),
                'exercise', json(_ex.exercise_json)
            )
        )
        FROM _ex
        WHERE _ex.template_id = _templates.id
    ) AS exercises
FROM _templates
;
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
    HAVING max(w.start)
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
