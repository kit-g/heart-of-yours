part of '../../heart_db.dart';

/// v11: the catalog re-keys from `name` to the server's uuid `id`.
///
/// The backend now serves `name` (and `instructions`) as *localized display
/// copy*, resolved per request from `Accept-Language` — the same exercise
/// arrives under a different name per device language, and even the English
/// copy is mutable server-side. A primary key must survive that, so identity
/// moves to `id`: v7 uuids the server has sent since schema v2, and that
/// client-created exercises mint themselves.
///
/// `name` was also the value every referencing table stored, so this is a
/// rebuild of the whole chain, v3-style (create, copy, drop, rename, one
/// statement per entry): `exercises` itself, `workout_exercises` and
/// `template_exercises` (their `exercise_id` values become uuids),
/// `exercise_details` (`exercise_name` becomes `exercise_id`), and `sets` —
/// not because its values change (it references `workout_exercises.id`, which
/// is stable) but because of drop order, see below. Exercise chart preferences
/// (`charts.data`) re-key by an UPDATE, no rebuild.
///
/// Two rules the statement order obeys:
///
/// - **Copies run against live parents.** Foreign keys are ON during the
///   migration (`onConfigure`), so each `_new` table is populated only after
///   the `_new` parent it references is.
/// - **Drops go leaf-first, and only after every table referencing the
///   dropped one is itself gone.** With foreign keys ON, `DROP TABLE` runs an
///   implicit `DELETE FROM` first, and `ON DELETE CASCADE` would fire into
///   any surviving child — dropping old `workout_exercises` before old `sets`
///   would wipe every set on the device. The `_new` tables are immune: they
///   reference `_new` parents, never the tables being dropped.
///
/// The final renames rewrite the `REFERENCES exercises_new` /
/// `workout_exercises_new` clauses inside the other `_new` tables to the real
/// names (SQLite ≥ 3.25 ALTER TABLE RENAME semantics; we bundle our own).
///
/// The copy backfills `id` for any row that predates schema v2 or never
/// re-synced: a freshly minted v7-shaped uuid (millisecond timestamp +
/// randomness, built inline so it evaluates per row). Practically every row
/// already carries a server id — the catalog is rewritten on every launch —
/// so this is a last-resort guard against a NOT NULL violation, not a path
/// with meaningful traffic.
///
/// `validated` rides along on the new DDL rather than a separate ALTER: the
/// tri-state provenance flag for the served copy — 1 when a human reviewed
/// this locale's translation, 0 when machine-authored (the client marks it),
/// NULL when the exercise carries no library-managed copy (user-created).
/// `key` too: the env-stable content slug shared deep links carry (a uuid
/// only resolves in the database that minted it) — NULL for user-created
/// exercises, and for every pre-existing row until the next catalog sync
/// fills it in.
const rekeyExercisesCreate = '''
CREATE TABLE exercises_new
(
    id               TEXT NOT NULL PRIMARY KEY,
    key              TEXT,
    name             TEXT NOT NULL,
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
    movement         TEXT,
    health           TEXT,
    validated        INT,
    CHECK (own IN (0, 1)),
    CHECK (archived IN (0, 1)),
    CHECK (own = 1 OR user_id IS NULL),
    CHECK (length(name) > 0),
    CHECK (asset_width IS NULL OR asset_width > 0),
    CHECK (asset_height IS NULL OR asset_height > 0),
    CHECK (thumbnail_width IS NULL OR thumbnail_width > 0),
    CHECK (thumbnail_height IS NULL OR thumbnail_height > 0),
    CHECK (validated IS NULL OR validated IN (0, 1))
);
''';

const rekeyExercisesCopy = '''
INSERT INTO exercises_new (id, name, category, target, asset, asset_width, asset_height,
                           thumbnail, thumbnail_width, thumbnail_height, instructions,
                           user_id, muscles, own, archived, movement, health)
SELECT coalesce(
           id,
           printf(
               '%.8s-%.4s-7%.3s-%.1s%.3s-%.12s',
               printf('%012x', CAST(strftime('%s', 'now') AS INTEGER) * 1000),
               substr(printf('%012x', CAST(strftime('%s', 'now') AS INTEGER) * 1000), 9, 4),
               lower(hex(randomblob(2))),
               substr('89ab', (abs(random()) % 4) + 1, 1),
               lower(hex(randomblob(2))),
               lower(hex(randomblob(6)))
           )
       ),
       name, category, target, asset, asset_width, asset_height,
       thumbnail, thumbnail_width, thumbnail_height, instructions,
       user_id, muscles, own, archived, movement, health
FROM exercises;
''';

const rekeyWorkoutExercisesCreate = '''
CREATE TABLE workout_exercises_new
(
    workout_id     TEXT NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
    exercise_id    TEXT NOT NULL REFERENCES exercises_new (id) ON DELETE CASCADE,
    id             TEXT NOT NULL PRIMARY KEY,
    exercise_order INT
);
''';

/// The name join is against `exercises_new` deliberately: old `exercises` has
/// rows with NULL ids, the new table carries the minted ones, and names are
/// still unique at this instant — they were the old primary key.
const rekeyWorkoutExercisesCopy = '''
INSERT INTO workout_exercises_new (workout_id, exercise_id, id, exercise_order)
SELECT we.workout_id, e.id, we.id, we.exercise_order
FROM workout_exercises we
JOIN exercises_new e ON e.name = we.exercise_id;
''';

const rekeySetsCreate = '''
CREATE TABLE sets_new
(
    exercise_id TEXT    NOT NULL REFERENCES workout_exercises_new (id) ON DELETE CASCADE,
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
''';

const rekeySetsCopy = '''
INSERT INTO sets_new (exercise_id, id, completed, weight, reps, duration, distance)
SELECT exercise_id, id, completed, weight, reps, duration, distance FROM sets;
''';

const rekeyTemplateExercisesCreate = '''
CREATE TABLE template_exercises_new
(
    id          TEXT NOT NULL PRIMARY KEY,
    template_id TEXT NOT NULL REFERENCES templates ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises_new (id) ON DELETE CASCADE,
    description TEXT
);
''';

const rekeyTemplateExercisesCopy = '''
INSERT INTO template_exercises_new (id, template_id, exercise_id, description)
SELECT te.id, te.template_id, e.id, te.description
FROM template_exercises te
JOIN exercises_new e ON e.name = te.exercise_id;
''';

const rekeyExerciseDetailsCreate = '''
CREATE TABLE exercise_details_new
(
    exercise_id TEXT NOT NULL REFERENCES exercises_new (id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL,
    rest_timer  INTEGER,
    unit_system TEXT,
    PRIMARY KEY (exercise_id, user_id),
    CHECK (unit_system IS NULL OR unit_system IN ('imperial', 'metric'))
);
''';

const rekeyExerciseDetailsCopy = '''
INSERT INTO exercise_details_new (exercise_id, user_id, rest_timer, unit_system)
SELECT e.id, ed.user_id, ed.rest_timer, ed.unit_system
FROM exercise_details ed
JOIN exercises_new e ON e.name = ed.exercise_name;
''';

/// Exercise chart preferences store their exercise inside the `data` JSON
/// blob (`{"exerciseName": …}`). The value becomes the exercise id — the key
/// keeps its (now stale) name until the next heart_models major renames it.
/// `json_valid` skips any malformed legacy blob without aborting the
/// migration, and the EXISTS guard leaves a preference whose name no longer
/// resolves untouched rather than nulling it into a broken row.
const rekeyExerciseCharts = '''
UPDATE charts
SET data = json_set(
    data,
    '\$.exerciseName',
    (SELECT e.id FROM exercises_new e WHERE e.name = json_extract(charts.data, '\$.exerciseName'))
)
WHERE type = 'exercise'
  AND json_valid(data)
  AND EXISTS (SELECT 1 FROM exercises_new e WHERE e.name = json_extract(charts.data, '\$.exerciseName'));
''';

const rekeyDropSets = '''
DROP TABLE sets;
''';

const rekeyDropWorkoutExercises = '''
DROP TABLE workout_exercises;
''';

const rekeyDropTemplateExercises = '''
DROP TABLE template_exercises;
''';

const rekeyDropExerciseDetails = '''
DROP TABLE exercise_details;
''';

const rekeyDropExercises = '''
DROP TABLE exercises;
''';

const rekeyExercisesRename = '''
ALTER TABLE exercises_new RENAME TO exercises;
''';

const rekeyWorkoutExercisesRename = '''
ALTER TABLE workout_exercises_new RENAME TO workout_exercises;
''';

const rekeySetsRename = '''
ALTER TABLE sets_new RENAME TO sets;
''';

const rekeyTemplateExercisesRename = '''
ALTER TABLE template_exercises_new RENAME TO template_exercises;
''';

const rekeyExerciseDetailsRename = '''
ALTER TABLE exercise_details_new RENAME TO exercise_details;
''';

// The indexes died with the dropped tables; recreate them on the successors,
// keeping the established (if quirky, see 0001/0003) global names.

const rekeyWorkoutExercisesIndex1 = '''
CREATE INDEX IF NOT EXISTS exercise_idx ON workout_exercises (exercise_id);
''';

const rekeyWorkoutExercisesIndex2 = '''
CREATE INDEX IF NOT EXISTS workout_idx ON workout_exercises (workout_id);
''';

const rekeySetsIndex = '''
CREATE INDEX IF NOT EXISTS sets_exercise_idx ON sets (exercise_id);
''';

const rekeyTemplateExercisesIndex = '''
CREATE INDEX IF NOT EXISTS template_idx ON template_exercises (template_id);
''';

const rekeyExerciseDetailsIndex = '''
CREATE INDEX IF NOT EXISTS exercise_name_idx ON exercise_details (exercise_id);
''';

/// Which locale the cached copy of a synced table is in — the requested
/// `Accept-Language` tag, recorded beside `synced_at` when the catalog is
/// stored. Cached content is per-locale, so the locale is part of the cache
/// key: a mismatch against the device's current tag means the localized
/// columns are stale even when `synced_at` is fresh.
const addSyncsLocale = '''
ALTER TABLE syncs ADD COLUMN locale TEXT;
''';
