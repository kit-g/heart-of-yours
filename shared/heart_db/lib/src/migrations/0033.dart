part of '../../heart_db.dart';

/// A coach's notes on their clients (#556), kept so they open offline:
/// ciphertext only, as the server holds it, opened in memory each time. A
/// note written or deleted here and not yet sent is `pending`; a deletion
/// waits as a row marked `deleted`, so it isn't shown meanwhile.
const createCoachNotes = '''
CREATE TABLE IF NOT EXISTS coach_notes
(
    user_id       TEXT    NOT NULL,
    id            TEXT    NOT NULL,
    connection_id TEXT,
    content       TEXT    NOT NULL,
    updated_at    TEXT    NOT NULL,
    pending       INTEGER NOT NULL DEFAULT 0,
    deleted       INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, id)
);
''';
