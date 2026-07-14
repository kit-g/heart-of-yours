part of '../../heart_db.dart';

/// Collapse any pre-existing duplicate chart preferences (same user, metric and
/// target) to a single row, so the unique index below can be created. Keeps the
/// earliest row of each group.
const dedupeChartPreferences = """
DELETE FROM charts
WHERE id NOT IN (
    SELECT min(id)
    FROM charts
    GROUP BY user_id, type, data
);
""";

/// Stop the same chart from being stored twice. Paired with the REPLACE insert
/// in `saveChartPreference`, re-adding a chart now overwrites rather than dupes.
const chartsUniqueIndex = """
CREATE UNIQUE INDEX IF NOT EXISTS charts_unique_idx ON charts (user_id, type, data);
""";
