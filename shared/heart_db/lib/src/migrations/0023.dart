part of '../../heart_db.dart';

/// "Not today" (#312, heart-api#202): a day the user chose not to train, and
/// the program session it set aside, when one was due. A program's position
/// reads its skips beside its workouts.
///
/// The session and the program are links, never requirements, as on the
/// server: no foreign key, and each goes null by hand when what it names is
/// deleted. Weather is JSON, as on the wire. The health snapshot #312 records
/// beside a skip has no column here, or anywhere that syncs.
const createSkips = '''
CREATE TABLE IF NOT EXISTS skips
(
    id          TEXT NOT NULL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    at          TEXT NOT NULL,
    reason      TEXT,
    weather     TEXT,
    template_id TEXT,
    program_id  TEXT
);
''';

const skipsProgramIndex = 'CREATE INDEX IF NOT EXISTS skips_program_idx ON skips (user_id, program_id);';
