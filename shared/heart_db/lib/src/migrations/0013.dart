part of '../../heart_db.dart';

/// v13: the upsync ledger (heart-of-yours#96).
///
/// When an anonymous session becomes an account, every row the device holds
/// under that uid is replayed to the server, one create at a time. The replay
/// can be interrupted — a killed app, a dropped connection — and has to resume
/// without posting a row twice, and the "n uploaded, n already there" line at
/// the end has to count what happened across every attempt. Workouts and goals
/// carry a `synced` flag for that; custom exercises, unit preferences, folders
/// and templates do not, and giving each a flag that only means something for
/// an anonymous uid muddles their tables. So the replay keeps its own ledger:
/// one row per confirmed (resource, id), with the server's answer, dropped once
/// the run completes. The run itself is owed through a `syncs` row keyed
/// `upsync:<uid>`, the way the health backfill records its progress.
const upsync = '''
CREATE TABLE IF NOT EXISTS upsync
(
    user_id  TEXT NOT NULL,
    resource TEXT NOT NULL,
    id       TEXT NOT NULL,
    outcome  TEXT NOT NULL,
    PRIMARY KEY (user_id, resource, id)
);
''';
