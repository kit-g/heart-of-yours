part of '../../heart_db.dart';

/// v9: readings from the device's health store — HealthKit / Health Connect.
///
/// **Device-only, by decision.** There is no server counterpart and no `synced`
/// column: the OS store is already the system of record and already survives a
/// reinstall, so this table is a queryable local mirror, not a staging area.
/// If it is lost, a re-read rebuilds it. See `docs/2026-08-02.wearables.md`.
///
/// The primary key is the platform's own sample UUID, which makes an import
/// idempotent — overlapping windows can be re-read as often as we like and
/// collide instead of accumulating.
///
/// `source_id` is not decoration. HealthKit holds steps from the phone *and*
/// the watch *and* any syncing third-party app, all covering the same hour, as
/// distinct samples. Any aggregate over a cumulative metric has to reconcile
/// across sources rather than sum — see `getDailyHealth`.
const healthSamples = """
CREATE TABLE IF NOT EXISTS health_samples
(
    id           TEXT NOT NULL PRIMARY KEY, -- the platform's sample UUID
    user_id      TEXT NOT NULL,
    metric       TEXT NOT NULL,
    value        REAL NOT NULL,
    unit         TEXT NOT NULL,
    start        TEXT NOT NULL, -- ISO8601, always UTC
    "end"        TEXT NOT NULL, -- ISO8601, always UTC
    source_id    TEXT,          -- bundle id of the writing app
    source_name  TEXT,
    device_model TEXT,          -- iOS only; Health Connect has no equivalent
    is_manual    INTEGER NOT NULL DEFAULT 0
);
""";

/// Every read is "this metric, this user, this window", so the index leads with
/// the two equality columns and carries `start` for the range and the ordering.
const healthSamplesIndex = '''
CREATE INDEX IF NOT EXISTS health_samples_lookup
    ON health_samples (user_id, metric, start);
''';
