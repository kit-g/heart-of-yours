part of '../../heart_db.dart';

/// A workout someone's coach logged for them (#560): who, by id and by the
/// name the server gives, so History can say so. Kept whatever the coaching
/// switches say (`docs/opt-in.md`).
const addWorkoutLoggedBy = 'ALTER TABLE workouts ADD COLUMN logged_by TEXT';
const addWorkoutLoggedByName = 'ALTER TABLE workouts ADD COLUMN logged_by_name TEXT';
