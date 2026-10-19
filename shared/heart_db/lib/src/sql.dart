/// The session in progress *on this device*.
///
/// `synced = 0` is what makes it this device's: the app never posts an
/// unfinished workout — `saveWorkout` runs on finish, and `syncPendingWorkouts`
/// only pushes `isCompleted && !synced` — so a synced row with no `end` is an
/// abandoned session the server handed us, not one the user is in the middle
/// of. Without the clause, pulling an account's history (heart-of-yours#113)
/// resurrects the oldest of those as an open workout hours-old in the hundreds.
const activeWorkout = """
WITH
  _workout AS (
    SELECT *
    FROM workouts
    WHERE "end" IS NULL
      AND synced = 0
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
    INNER JOIN exercises ON exercises.id = workout_exercises.exercise_id
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
    _workout.synced,
    _workout.note,
    _workout.pauses,
    _workout.template_id AS templateId,
    _workout.program_id AS programId,
    _workout.unread,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'order', _ex.exercise_order,
                'note', _ex.note,
                'exercise', json(_ex.exercise_json),
                -- what a template planned for it, spread back by toWorkout
                'plan', json(_ex.plan),
                -- sets this build could not read, put back by toWorkout (#277)
                'unread', json(_ex.unread),
                'sets', (
                    SELECT json_group_array(
                        json_object(
                            'id', _sets.id,
                            'weight', _sets.weight,
                            'reps', _sets.reps,
                            'duration', _sets.duration,
                            'distance', _sets.distance,
                            'completed', _sets.completed,
                            'set_type', _sets.set_type,
                            'rpe', _sets.rpe,
                            'completed_at', _sets.completed_at,
                            'target', json(_sets.target)
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
    INNER JOIN exercises ON exercises.id = workout_exercises.exercise_id
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
    _workout.synced,
    _workout.note,
    _workout.pauses,
    _workout.template_id AS templateId,
    _workout.program_id AS programId,
    _workout.unread,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'order', _ex.exercise_order,
                'note', _ex.note,
                'exercise', json(_ex.exercise_json),
                -- what a template planned for it, spread back by toWorkout
                'plan', json(_ex.plan),
                -- sets this build could not read, put back by toWorkout (#277)
                'unread', json(_ex.unread),
                'sets', (
                    SELECT json_group_array(
                        json_object(
                            'id', _sets.id,
                            'weight', _sets.weight,
                            'reps', _sets.reps,
                            'duration', _sets.duration,
                            'distance', _sets.distance,
                            'completed', _sets.completed,
                            'set_type', _sets.set_type,
                            'rpe', _sets.rpe,
                            'completed_at', _sets.completed_at,
                            'target', json(_sets.target)
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
    INNER JOIN exercises ON exercises.id = workout_exercises.exercise_id
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
    _workouts.synced,
    _workouts.note,
    _workouts.pauses,
    _workouts.template_id AS templateId,
    _workouts.program_id AS programId,
    _workouts.unread,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'order', _ex.exercise_order,
                'note', _ex.note,
                'exercise', json(_ex.exercise_json),
                -- what a template planned for it, spread back by toWorkout
                'plan', json(_ex.plan),
                -- sets this build could not read, put back by toWorkout (#277)
                'unread', json(_ex.unread),
                'sets', (
                    SELECT json_group_array(
                        json_object(
                            'id', _sets.id,
                            'weight', _sets.weight,
                            'reps', _sets.reps,
                            'duration', _sets.duration,
                            'distance', _sets.distance,
                            'completed', _sets.completed,
                            'set_type', _sets.set_type,
                            'rpe', _sets.rpe,
                            'completed_at', _sets.completed_at,
                            'target', json(_sets.target)
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

const removeUnfinished = '''
DELETE
FROM sets
WHERE completed = 0
  AND exercise_id IN (
          SELECT id
          FROM workout_exercises
          WHERE workout_id = ?
      );
''';

/// The targets a workout's sets hold in the mirror (#173): what a server copy
/// without them must not wipe, since the server keeps no target on a
/// workout's sets.
const setTargetsOfWorkout = '''
SELECT
    s.id AS id,
    s.target AS target
FROM sets s
INNER JOIN workout_exercises we ON we.id = s.exercise_id
WHERE we.workout_id = ?
  AND s.target IS NOT NULL
;
''';

/// Writes the workout row in place. Never `INSERT OR REPLACE` here: with
/// foreign keys on, REPLACE is a delete + insert, and the delete cascades
/// through `workout_exercises` into `sets` (heart-of-yours#85).
const upsertWorkout = '''
INSERT INTO workouts (id, start, user_id, name, "end", images, synced, note, pauses, template_id, program_id, unread)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
    start   = EXCLUDED.start,
    user_id = EXCLUDED.user_id,
    name    = EXCLUDED.name,
    "end"   = EXCLUDED."end",
    images  = EXCLUDED.images,
    synced  = EXCLUDED.synced,
    note    = EXCLUDED.note,
    pauses  = EXCLUDED.pauses,
    -- links, never requirements (#346): a shallow payload (a list page) that
    -- leaves them out leaves the stored ones; one authoritative for the
    -- workout (the arguments before the last) may also let them go
    template_id = CASE WHEN ? THEN EXCLUDED.template_id ELSE coalesce(EXCLUDED.template_id, workouts.template_id) END,
    program_id  = CASE WHEN ? THEN EXCLUDED.program_id ELSE coalesce(EXCLUDED.program_id, workouts.program_id) END,
    -- the exercises this build could not read belong with the children: only
    -- a payload authoritative for them (the last argument) replaces them
    unread  = CASE WHEN ? THEN EXCLUDED.unread ELSE workouts.unread END;
''';

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
    INNER JOIN exercises ON exercises.id = template_exercises.exercise_id
    WHERE template_id IN (SELECT id FROM _templates)
)
SELECT
    _templates.id,
    _templates.name,
    _templates.order_in_parent AS "order",
    _templates.unread,
    _templates.program_id AS programId,
    _templates.note,
    _templates.joined,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'sets', json(_ex.description),
                'exercise', json(_ex.exercise_json),
                'plan', json(_ex.plan)
            )
        )
        FROM _ex
        WHERE _ex.template_id = _templates.id
    ) AS exercises,
    CASE
        WHEN folder.id IS NULL THEN NULL
        ELSE json_object(
            'id', folder.id,
            'name', folder.name,
            'order', folder.order_index,
            'createdAt', folder.created_at
        )
    END AS folder
FROM _templates
LEFT JOIN template_folders AS folder ON folder.id = _templates.folder_id
;
""";

const getTemplateFolders = '''
SELECT
    template_folders.*,
    (
        SELECT count(*)
        FROM templates
        WHERE templates.folder_id = template_folders.id
    ) AS template_count
FROM template_folders
WHERE user_id = ?
ORDER BY order_index, name COLLATE NOCASE
;
''';

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
    INNER JOIN exercises ON exercises.id = template_exercises.exercise_id
    WHERE template_id IN (SELECT id FROM _templates)
)
SELECT
    id,
    name,
    order_in_parent AS "order",
    unread,
    (
        SELECT json_group_array(
            json_object(
                'id', _ex.id,
                'sets', json(_ex.description),
                'exercise', json(_ex.exercise_json),
                'plan', json(_ex.plan)
            )
        )
        FROM _ex
        WHERE _ex.template_id = _templates.id
    ) AS exercises
FROM _templates
;
""";

const getExerciseHistory = '''
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
''';

/// Every completed set of one exercise with its workout's identity and start
/// — the raw material [LocalDatabase.getRecord] folds into the records map.
/// One query instead of per-metric aggregates so a record can carry the *set*
/// it happened on (its own reps, its own date), never two independent maxima
/// glued together. Warm-ups are no one's record (heart-api#83); `IS NOT`
/// keeps the sets stored before types existed, whose column is null.
const recordSets = '''
SELECT
    sets.weight,
    sets.reps,
    sets.duration,
    sets.distance,
    workouts.id AS workout_id,
    workouts.start AS start
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
  AND sets.set_type IS NOT 'warmup'
ORDER BY workouts.start, workouts.id;
''';

/// [recordSets] as of one workout: its own sets and every earlier
/// workout's, so the records it set stay its own after a later session beats
/// them.
const recordSetsAsOf = '''
SELECT
    sets.weight,
    sets.reps,
    sets.duration,
    sets.distance,
    workouts.id AS workout_id,
    workouts.start AS start
FROM sets
INNER JOIN workout_exercises we ON sets.exercise_id = we.id
INNER JOIN workouts ON we.workout_id = workouts.id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
  AND sets.set_type IS NOT 'warmup'
  AND (workouts.id = ? OR workouts.start < (SELECT start FROM workouts WHERE id = ?))
ORDER BY workouts.start, workouts.id;
''';

const getWeightHistory = '''
SELECT
    MAX(sets.weight) AS "value",
    workouts.start AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
  AND sets.set_type IS NOT 'warmup'
GROUP BY workouts.id
ORDER BY "when" DESC
LIMIT ?
;
''';

const getRepsHistory = '''
SELECT
    MAX(sets.reps) AS "value",
    workouts.start AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
  AND sets.set_type IS NOT 'warmup'
GROUP BY workouts.id 
ORDER BY "when" DESC
LIMIT ?
;
''';

const getDurationHistory = '''
SELECT
    MAX(sets.duration) AS "value",
    workouts.start AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
  AND sets.set_type IS NOT 'warmup'
GROUP BY workouts.id 
ORDER BY "when" DESC
LIMIT ?
;
''';

const getDistanceHistory = '''
SELECT
    MAX(sets.distance) AS "value",
    workouts.start AS "when"  
FROM sets
INNER JOIN main.workout_exercises we ON we.id = sets.exercise_id
INNER JOIN main.workouts ON workouts.id = we.workout_id
WHERE workouts.user_id = ?
  AND we.exercise_id = ?
  AND sets.completed
  AND sets.set_type IS NOT 'warmup'
GROUP BY workouts.id
ORDER BY "when" DESC
LIMIT ?
;
''';

final getPreviousExercises = _previousExercises('');

/// [getPreviousExercises] as of a moment: last time *before* the workout
/// starting at the second argument — what a past workout's editor shows,
/// where the newest session would otherwise be the one being edited.
final getPreviousExercisesBefore = _previousExercises('AND julianday(w.start) < julianday(?)');

/// [getPreviousExercises] within one template (#172): last time this
/// template, or a program session, was run — the template's id second.
final getPreviousExercisesInTemplate = _previousExercises('AND w.template_id = ?');

/// [getPreviousExercisesInTemplate] as of a moment, for a past workout.
final getPreviousExercisesInTemplateBefore = _previousExercises(
  'AND w.template_id = ? AND julianday(w.start) < julianday(?)',
);

String _previousExercises(String before) =>
    """
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
      -- finished sessions only: the workout in progress is never "last
      -- time", and after a restart mid-workout it was the newest one
      AND w."end" IS NOT NULL
      $before
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
            'distance', s.distance,
            'set_type', s.set_type,
            -- when last time was: the picker ranks search results by it (#135)
            'workout_start', _recent.last_workout_date
        )
    ) AS sets
FROM _recent
JOIN sets s ON s.exercise_id = _recent.workout_exercise_id
WHERE s.completed = 1
GROUP BY _recent.exercise_id, _recent.workout_exercise_id, _recent.last_workout_date
;
""";

/// Completed working sets per exercise per finished workout started in a
/// window, with the exercise's muscle tagging: the muscle map's read.
const muscleSets = '''
SELECT
    w.start AS start,
    e.muscles AS muscles,
    e.target AS target,
    count(*) AS sets
FROM workouts w
INNER JOIN workout_exercises we ON we.workout_id = w.id
INNER JOIN sets s ON s.exercise_id = we.id
LEFT JOIN exercises e ON e.id = we.exercise_id
WHERE w.user_id = ?
  AND w."end" IS NOT NULL
  AND w.start >= ?
  AND w.start < ?
  AND s.completed
  AND s.set_type IS NOT 'warmup'
GROUP BY w.id, we.exercise_id
;
''';

/// The muscle map's read with the rest of the exercise, for the pattern lens
/// (#341): the workout, the movement and the target beside the tagging.
const lensSets = '''
SELECT
    w.id AS workout_id,
    we.exercise_id AS exercise_id,
    w.start AS start,
    e.muscles AS muscles,
    e.movement AS movement,
    e.target AS target,
    count(*) AS sets
FROM workouts w
INNER JOIN workout_exercises we ON we.workout_id = w.id
INNER JOIN sets s ON s.exercise_id = we.id
LEFT JOIN exercises e ON e.id = we.exercise_id
WHERE w.user_id = ?
  AND w."end" IS NOT NULL
  AND w.start >= ?
  AND w.start < ?
  AND s.completed
  AND s.set_type IS NOT 'warmup'
GROUP BY w.id, we.exercise_id
;
''';

/// Finished workouts that started in a window: every period's count (#339).
const workoutCountBetween = '''
SELECT count(*) AS c
FROM workouts
WHERE start >= ?
  AND start < ?
  AND "end" IS NOT NULL
  AND user_id = ?
;
''';

/// Every finished workout there has been.
const workoutCount = '''
SELECT count(*) AS c
FROM workouts
WHERE "end" IS NOT NULL
  AND user_id = ?
;
''';

/// What the dashboard's training charts are drawn from (#137): every finished
/// workout started in a window, with its working sets counted and its volume
/// summed across every exercise in it.
///
/// Warm-ups count toward neither, as in every other chart. Volume is weight
/// times reps, and an assisted exercise's weight is the help it gave rather
/// than a load lifted, so it adds none. The `LEFT JOIN`s keep a workout with
/// no working sets at all: it still took time, which the duration chart shows.
///
/// `/*discarded:s*/` sits inside the join, after the warm-up clause, where the
/// rest of the counts carry it: a set the user marks as a bad entry (#428)
/// drops out of both totals once that marker is honoured.
const trainingTotals = '''
SELECT
    w.start AS start,
    w."end" AS "end",
    w.pauses AS pauses,
    count(s.id) AS sets,
    coalesce(
        sum(
            CASE e.category
                WHEN 'Assisted Body Weight' THEN 0
                ELSE coalesce(s.weight, 0) * coalesce(s.reps, 0)
            END
        ),
        0
    ) AS volume
FROM workouts w
LEFT JOIN workout_exercises we ON we.workout_id = w.id
LEFT JOIN sets s ON s.exercise_id = we.id
    AND s.completed
    AND s.set_type IS NOT 'warmup'
    /*discarded:s*/
LEFT JOIN exercises e ON e.id = we.exercise_id
WHERE w.user_id = ?
  AND w."end" IS NOT NULL
  AND w.start >= ?
  AND w.start < ?
GROUP BY w.id
;
''';
