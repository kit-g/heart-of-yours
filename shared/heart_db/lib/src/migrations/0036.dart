part of '../../heart_db.dart';

/// What a day looked like at the moment it was set aside (heart-of-yours#445):
/// the training before it, and what Health had for it. Taken once, when the
/// skip is made, so a workout deleted later or a day's steps still climbing
/// never change what the skip's page says.
///
/// Device-only, like `health_samples` (`docs/2026-09-05.health-data.md`): no
/// remote counterpart, never exported, never replayed. `body` is the health
/// half, a column of its own so that forgetting the health mirror empties it
/// and leaves the training half. Keyed by the skip, which syncs without it.
///
/// 36, with 35 another branch's (#616). The runner takes only versions above
/// the stored one, so 35 has to reach main first: a device that had opened
/// at 36 would never go back for it.
const createSkipSnapshots = '''
CREATE TABLE IF NOT EXISTS skip_snapshots
(
    skip_id  TEXT NOT NULL PRIMARY KEY,
    user_id  TEXT NOT NULL,
    taken_at TEXT NOT NULL,
    training TEXT NOT NULL,
    body     TEXT
);
''';
