part of '../../heart_db.dart';

/// What a program workout was asked to be (#566, #558): the planned session as
/// it stood when the workout started, each planned set naming the set it
/// became. The server takes it once the workout is there
/// (`PUT /workouts/:id/plan`), and keeps the first one it gets, so `synced`
/// turns 1 once it has. The plan is the device's JSON, kept as written.
///
/// Recorded whatever the coaching switches say (`docs/opt-in.md`): it is what a
/// coach would compare against, and a plan not recorded when the workout
/// started can't be recovered later. A workout's plan goes with it.
const createWorkoutPlans = '''
CREATE TABLE IF NOT EXISTS workout_plans
(
    workout_id TEXT    NOT NULL PRIMARY KEY REFERENCES workouts (id) ON DELETE CASCADE,
    user_id    TEXT    NOT NULL,
    plan       TEXT    NOT NULL,
    synced     INTEGER NOT NULL DEFAULT 0
);
''';
