

// ✅ for reps-only exercises, we take the best single set
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
GROUP BY workouts.id
ORDER BY "when" DESC
LIMIT ?
;
""";
