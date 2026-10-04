part of '../../heart_db.dart';

/// A workout's pauses (#134). The wire model sends its closed pauses on every
/// save, an empty list included, and the server takes a present key as the new
/// value: a mirror without them would re-save every workout it reads back as
/// never paused, and clear what another device recorded.
const addWorkoutPauses = 'ALTER TABLE workouts ADD COLUMN pauses TEXT';

/// The active workout's open pause, which never goes on the wire: without it a
/// cold start would come back running.
const addWorkoutPausedAt = 'ALTER TABLE workouts ADD COLUMN paused_at TEXT';

/// When a set was ticked: what a forgotten workout is offered to finish at.
const addSetCompletedAt = 'ALTER TABLE sets ADD COLUMN completed_at TEXT';
