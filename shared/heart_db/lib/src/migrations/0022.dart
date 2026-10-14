part of '../../heart_db.dart';

/// Programs, second round (heart-of-yours#346, heart-api#227–#234): what the
/// server now keeps on a program, its steps, its bases and the template
/// exercises its sessions are made of, kept here so a save from this device
/// never drops it.
///
/// A program's lighter cycles, phases and test sessions, as JSON, as on the
/// wire; null for none.
const addProgramDeload = 'ALTER TABLE programs ADD COLUMN deload TEXT';
const addProgramPhases = 'ALTER TABLE programs ADD COLUMN phases TEXT';
const addProgramTests = 'ALTER TABLE programs ADD COLUMN tests TEXT';

/// When a session joined its program, as the device saw it: what the position
/// reads before the template id's own time. A program's `joined` is read off
/// its sessions, as its session list is.
const addTemplateJoined = 'ALTER TABLE templates ADD COLUMN joined TEXT';

/// A ladder's advance names the exercises it moved between, and the workout
/// that moved it.
const addProgramActionFrom = 'ALTER TABLE program_actions ADD COLUMN from_exercise TEXT';
const addProgramActionTo = 'ALTER TABLE program_actions ADD COLUMN to_exercise TEXT';
const addProgramActionWorkout = 'ALTER TABLE program_actions ADD COLUMN workout_id TEXT';

/// The template exercise a base belongs to, when one lift keeps two.
const addProgramBaseSlot = 'ALTER TABLE program_bases ADD COLUMN slot TEXT';

/// What a template plans for an exercise beyond its sets: rest, superset,
/// an open slot's pattern, a rep total. A JSON object of the keys the
/// exercise speaks about, a null among them included: heart_models sends a
/// key it read, null or not, and leaves out one it never had, which keeps
/// the server's. A workout started from a template carries the same.
const addTemplateExercisePlan = 'ALTER TABLE template_exercises ADD COLUMN plan TEXT';
const addWorkoutExercisePlan = 'ALTER TABLE workout_exercises ADD COLUMN plan TEXT';
