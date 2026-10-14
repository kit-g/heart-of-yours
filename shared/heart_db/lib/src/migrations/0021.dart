part of '../../heart_db.dart';

/// Programs (heart-of-yours#346, heart-api#86): templates on a schedule, with
/// what the user did to steer them and the bases their rules grow. Version 20
/// is #173's, which merges first.
///
/// A program's own fields are its columns; `days`, `rules` and `sessions` are
/// JSON, as they are on the wire. `sessions` is the order the server last gave,
/// and the order a create made: the session templates themselves say which
/// program they belong to, so a deleted session drops out on read.
const createPrograms = '''
CREATE TABLE IF NOT EXISTS programs
(
    id             TEXT    NOT NULL PRIMARY KEY,
    user_id        TEXT,
    name           TEXT    NOT NULL,
    note           TEXT,
    source         TEXT,
    per_week       INTEGER,
    days           TEXT,
    weeks          INTEGER,
    rules          TEXT,
    constraint_key TEXT,
    archived       INTEGER NOT NULL DEFAULT 0,
    sessions       TEXT,
    created_at     TEXT
);
''';

const programsUserIndex = 'CREATE INDEX IF NOT EXISTS programs_user_idx ON programs (user_id);';

/// History, not state: a program's position is folded from these beside its
/// workouts, and undoing a step deletes its row.
const createProgramActions = '''
CREATE TABLE IF NOT EXISTS program_actions
(
    id         TEXT    NOT NULL PRIMARY KEY,
    program_id TEXT    NOT NULL REFERENCES programs ON DELETE CASCADE,
    kind       TEXT    NOT NULL,
    week       INTEGER,
    at         TEXT    NOT NULL
);
''';

const programActionsIndex = 'CREATE INDEX IF NOT EXISTS program_actions_program_idx ON program_actions (program_id);';

/// Every value a growth rule has given an exercise, with its cause: a
/// workout, an action, or neither (the user's own). The cause carries no
/// foreign key: a base can arrive naming a workout this device has not paged
/// down yet. Deleting the cause deletes the base, by hand (`deleteWorkout`,
/// `deleteProgramAction`), as the server's cascade does.
const createProgramBases = '''
CREATE TABLE IF NOT EXISTS program_bases
(
    id          TEXT NOT NULL PRIMARY KEY,
    program_id  TEXT NOT NULL REFERENCES programs ON DELETE CASCADE,
    exercise_id TEXT NOT NULL,
    value       REAL NOT NULL,
    workout_id  TEXT,
    action_id   TEXT,
    at          TEXT NOT NULL
);
''';

const programBasesIndex = 'CREATE INDEX IF NOT EXISTS program_bases_program_idx ON program_bases (program_id);';

/// A session is a template naming its program. No foreign key: templates and
/// programs arrive from the server separately, in either order.
const addTemplateProgramId = 'ALTER TABLE templates ADD COLUMN program_id TEXT';

/// A one-line reason for the template ("big lifts for the quads"), from the
/// library or the user.
const addTemplateNote = 'ALTER TABLE templates ADD COLUMN note TEXT';

const templatesProgramIndex = 'CREATE INDEX IF NOT EXISTS templates_program_idx ON templates (program_id);';

/// What a workout was started from: links, never requirements. Either can
/// name a row this device does not hold.
const addWorkoutTemplateId = 'ALTER TABLE workouts ADD COLUMN template_id TEXT';
const addWorkoutProgramId = 'ALTER TABLE workouts ADD COLUMN program_id TEXT';

const workoutsProgramIndex = 'CREATE INDEX IF NOT EXISTS workouts_program_idx ON workouts (program_id);';

/// The program writes the server has not confirmed (heart-state's
/// `ProgramOwed`): a failed or unreached remote leg, sent again on the next
/// launch. No foreign key: a deletion is owed after its row is gone.
const createProgramsOwed = '''
CREATE TABLE IF NOT EXISTS programs_owed
(
    user_id    TEXT NOT NULL,
    row_kind   TEXT NOT NULL,
    id         TEXT NOT NULL,
    program_id TEXT NOT NULL,
    change     TEXT NOT NULL,
    PRIMARY KEY (row_kind, id)
);
''';
