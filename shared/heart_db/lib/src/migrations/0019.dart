part of '../../heart_db.dart';

/// What this build could not read, kept as it arrived (#277): exercises a
/// workout or a template carries in a shape this build predates, and sets an
/// exercise does. JSON lists, null for none. Read back into the payload
/// `fromJson` sees, where heart_models sets them aside again, so a save from
/// the mirror carries them to the server instead of deleting them. A
/// template's unread sets need no column: its sets are already a JSON list
/// in `template_exercises.description`.
const addWorkoutUnread = 'ALTER TABLE workouts ADD COLUMN unread TEXT';
const addWorkoutExerciseUnread = 'ALTER TABLE workout_exercises ADD COLUMN unread TEXT';
const addTemplateUnread = 'ALTER TABLE templates ADD COLUMN unread TEXT';
