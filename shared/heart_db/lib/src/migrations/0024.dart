part of '../../heart_db.dart';

/// Static content kept for the next launch (heart-of-yours#352): the program
/// library first. A file read whole from the content CDN, with what makes the
/// next read a cheap 304: the ETag it came with. Nobody's in particular, so
/// signing out keeps it.
const createContent = '''
CREATE TABLE IF NOT EXISTS content
(
    key       TEXT NOT NULL PRIMARY KEY,
    etag      TEXT,
    body      TEXT NOT NULL,
    stored_at TEXT DEFAULT (datetime('now') || '+00:00')
);
''';
