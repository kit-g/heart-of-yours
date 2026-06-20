part of '../../heart_db.dart';

/// v2: per-(user, exercise) unit preference. `NULL` falls back to the global
/// setting. Lives on `exercise_details` (keyed by exercise_name + user_id) so it
/// is scoped per user, alongside the rest timer — the catalog `exercises` table
/// is shared across users on a device.
const addExerciseUnitSystem = """
ALTER TABLE exercise_details ADD COLUMN unit_system TEXT
    CHECK (unit_system IS NULL OR unit_system IN ('imperial', 'metric'));
""";

const addExerciseId = """
ALTER TABLE exercises ADD COLUMN id TEXT;
""";