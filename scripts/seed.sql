DELETE FROM workouts WHERE TRUE;
DELETE FROM sets WHERE TRUE;
DELETE FROM workout_exercises WHERE TRUE;
DELETE FROM charts WHERE TRUE;
DELETE FROM syncs WHERE TRUE;



-- 1. create a stable temporary pool of 20 exercises
CREATE TEMP TABLE IF NOT EXISTS _exercise_pool AS
SELECT name, category FROM exercises LIMIT 20;

-- 2. generate Workouts (8 weeks, 3x/week = ~24 workouts)
WITH RECURSIVE days(d) AS (
    SELECT 0
    UNION ALL
    SELECT d + 1
    FROM days
    WHERE d < 55
),
workout_generation AS (
    SELECT
       strftime('%Y-%m-%dT%H:%M:%S.000Z', datetime('now', '-' || d || ' days', '+18 hours')) AS id,
       strftime('%Y-%m-%dT%H:%M:%S.000Z', datetime('now', '-' || d || ' days', '+18 hours')) AS start_time,
       strftime('%Y-%m-%dT%H:%M:%S.000Z', datetime('now', '-' || d || ' days', '+19 hours')) AS end_time,
       'HW4beTVvbTUPRxun9MXZxwKPjmC2' AS user_id,
       'Workout ' || (56 - d) AS name
    FROM days
    WHERE d % 7 IN (0, 2, 4)
)
INSERT OR IGNORE INTO workouts (
    id,
    start,
    "end",
    user_id,
    name
)
SELECT
    id,
    start_time,
    end_time,
    user_id,
    name
FROM workout_generation;

-- 3. assign 4 exercises per workout (~24 * 4 = ~96 workout_exercises)
INSERT OR IGNORE INTO workout_exercises (
    id,
    workout_id,
    exercise_id,
    exercise_order
)
SELECT
    strftime('%Y-%m-%dT%H:%M:%S.', workout_id) || printf('%03dZ', pos) AS id,
    workout_id,
    exercise_name,
    pos AS exercise_order
FROM (
     SELECT
         w.id as workout_id,
         ep.name as exercise_name,
         row_number() OVER (PARTITION BY w.id ORDER BY random()) as pos
     FROM workouts w
     CROSS JOIN _exercise_pool ep
     WHERE w.user_id = 'HW4beTVvbTUPRxun9MXZxwKPjmC2'
 )
WHERE pos <= 4;

-- 4. generate 3 sets for every exercise (~96 * 3 = ~288 sets)
INSERT OR IGNORE INTO sets (
        id,
        exercise_id,
        completed,
        weight,
        reps,
        duration,
        distance
)
SELECT
    -- create a unique ISO-like ID by manipulating the millisecond part of the exercise ID
    substr(we.id, 1, 20) || printf('%03dZ', (s.set_num * 100)) AS id,
    we.id AS exercise_id,
    1 AS completed,
    CASE
        WHEN ex.category IN ('Barbell', 'Dumbbell', 'Machine', 'Weighted Body Weight')
            THEN (40 + (abs(random() % 30)))
        WHEN ex.category = 'Assisted Body Weight'
            THEN (15 + (abs(random() % 15)))
        END AS weight,
    CASE
        WHEN ex.category IN ('Duration', 'Cardio') THEN NULL
        ELSE (8 + (abs(random() % 6)))
        END AS reps,
    CASE
        WHEN ex.category IN ('Duration', 'Cardio')
            THEN (60 + (abs(random() % 300)))
        END AS duration,
    CASE
        WHEN ex.category = 'Cardio'
            THEN (1.0 + (abs(random() % 5000) / 1000.0))
        END AS distance
FROM workout_exercises we
JOIN exercises ex ON we.exercise_id = ex.name
CROSS JOIN (
    SELECT 1 AS set_num UNION ALL
    SELECT 2 UNION ALL
    SELECT 3
) s;

DROP TABLE _exercise_pool;
