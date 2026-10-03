part of '../../heart_db.dart';

/// What a set was (warm-up, drop, failure) and how hard it felt, and the
/// workout's own note. The wire model sends all three on every save, nulls
/// included, so a mirror without them would re-save every workout it reads
/// back as plain, unrated sets and wipe what the server held (#151).
const addSetType = 'ALTER TABLE sets ADD COLUMN set_type TEXT';
const addSetRpe = 'ALTER TABLE sets ADD COLUMN rpe REAL';
const addWorkoutNote = 'ALTER TABLE workouts ADD COLUMN note TEXT';
