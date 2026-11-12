part of '../../heart_db.dart';

/// Coaching messages (#556): the inbox, and each thread's items as the server
/// stores them, so a thread opens offline. Items are ciphertext only, as the
/// server holds them: the words are opened in memory each time and never
/// written down. `position` is the server's order as this device met it; an
/// item written here and not yet sent has none, and is `pending`.
const createThreads = '''
CREATE TABLE IF NOT EXISTS threads
(
    user_id       TEXT    NOT NULL,
    id            TEXT    NOT NULL,
    connection_id TEXT,
    other_id      TEXT,
    other_name    TEXT,
    other_avatar  TEXT,
    unread        INTEGER NOT NULL DEFAULT 0,
    last_at       TEXT,
    cleared_at    TEXT,
    cleared_by    TEXT,
    PRIMARY KEY (user_id, id)
);
''';

const createThreadItems = '''
CREATE TABLE IF NOT EXISTS thread_items
(
    user_id      TEXT    NOT NULL,
    id           TEXT    NOT NULL,
    thread_id    TEXT    NOT NULL,
    sender_id    TEXT,
    kind         TEXT    NOT NULL,
    subject_type TEXT,
    subject_id   TEXT,
    content      TEXT    NOT NULL,
    commitment   TEXT    NOT NULL,
    tag          TEXT,
    tag_key      TEXT,
    at           TEXT    NOT NULL,
    created_at   TEXT,
    cursor       TEXT,
    position     INTEGER,
    pending      INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, id)
);
''';

const threadItemsIndex =
    'CREATE INDEX IF NOT EXISTS thread_items_thread ON thread_items (user_id, thread_id, position);';
