const getCardioDurationHistory = """
SELECT
    sum(coalesce(sets.duration, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";

const getCardioDistanceHistory = """
SELECT
    sum(coalesce(sets.distance, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";

const getAveragePaceHistory = """
SELECT
    sum(coalesce(sets.duration, 0)) / sum(coalesce(sets.distance, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
HAVING sum(sets.distance) > 0
ORDER BY "when" DESC
LIMIT ?
;
""";

// Volume-weighted average: Total Volume / Total Reps
const getAverageWorkingWeightHistory = """ 
SELECT
    sum(sets.weight * sets.reps) / sum(sets.reps) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
  AND sets.reps > 0
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";

// Specifically for weighted bodyweight exercises
const getTopSetWeightHistory = """
SELECT
    max(coalesce(sets.weight, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";


// for reps-only exercises, we take the best single set
const getMaxConsecutiveRepsHistory = """ 
SELECT
    max(sets.reps) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";

// sum of all reps across all sets performed in a workout
const getTotalRepsHistory = """
SELECT
    sum(coalesce(sets.reps, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";

// specifically for assisted exercises (pull-ups, etc.)
const getAssistanceWeightHistory = """
SELECT
    min(coalesce(sets.weight, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";

// sum of all duration fields for the exercise in a workout
const getTotalTimeUnderTensionHistory = """
SELECT
    sum(coalesce(sets.duration, 0)) AS "value",
    workouts.start AS "when"
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed = 1
GROUP BY workouts.id, workouts.start
ORDER BY "when" DESC
LIMIT ?
;
""";