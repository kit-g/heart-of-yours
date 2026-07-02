part of '../../heart_db.dart';

/// v3: fix `template_exercises.template_id` affinity.
///
/// It was declared `INTEGER` but references `templates.id`, which is `TEXT`.
/// Today's ids (UUIDs / ISO timestamps) aren't valid integer literals, so
/// SQLite's manifest typing stores them as TEXT anyway and the FK matches — but
/// a purely numeric id would be coerced to INTEGER (e.g. '0042' -> 42) and then
/// fail to match its TEXT parent. SQLite can't ALTER a column's type in place,
/// so the table is rebuilt: create with the corrected type, copy, drop, rename,
/// and recreate the index. Run inside the migration transaction, one statement
/// per entry (sqflite's execute runs a single statement).
///
/// Only `template_idx` is recreated — the original `exercise_idx` on this table
/// never existed (its name collided with the workout_exercises index and the
/// `IF NOT EXISTS` guard silently skipped it).
const rebuildTemplateExercisesCreate = """
CREATE TABLE template_exercises_new
(
    id          TEXT NOT NULL PRIMARY KEY,
    template_id TEXT NOT NULL REFERENCES templates ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises ON DELETE CASCADE,
    description TEXT
);
""";

const rebuildTemplateExercisesCopy = """
INSERT INTO template_exercises_new (id, template_id, exercise_id, description)
SELECT id, template_id, exercise_id, description FROM template_exercises;
""";

const rebuildTemplateExercisesDrop = """
DROP TABLE template_exercises;
""";

const rebuildTemplateExercisesRename = """
ALTER TABLE template_exercises_new RENAME TO template_exercises;
""";

const rebuildTemplateExercisesIndex = """
CREATE INDEX IF NOT EXISTS template_idx ON template_exercises (template_id);
""";

/// track whether a finished workout has been confirmed saved on the server.
///
/// Network failures could leave a workout persisted locally but never POSTed,
/// with no way to tell it apart from a synced one or to retry it. `synced`
/// marks that state: 0 until the API save succeeds, 1 afterwards.
///
/// Existing rows are backfilled to 1 — they predate the flag and are assumed
/// already on the server. Marking them 0 would re-POST them, and since
/// saveWorkout creates a fresh server id, that would duplicate every workout.
const addWorkoutSynced = """
ALTER TABLE workouts ADD COLUMN synced INTEGER NOT NULL DEFAULT 0;
""";

const backfillWorkoutSynced = """
UPDATE workouts SET synced = 1;
""";
