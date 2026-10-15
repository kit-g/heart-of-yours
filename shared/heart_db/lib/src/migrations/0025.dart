part of '../../heart_db.dart';

/// What a user goes easy on (heart-of-yours#396): the body areas and
/// movements they listed, by the content keys of the go-easy map (`knee`,
/// `jumping`). Health-shaped, so device-only like `health_samples`: no
/// remote counterpart, never exported, never replayed, and with the rest of
/// `heart.db` out of Android's cloud backup. Keyed by uid so another account
/// on this phone never sees it.
const createGoEasy = '''
CREATE TABLE IF NOT EXISTS go_easy
(
    user_id TEXT NOT NULL,
    key     TEXT NOT NULL,
    PRIMARY KEY (user_id, key)
);
''';
