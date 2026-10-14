part of '../../heart_db.dart';

/// What a set started from a template aims for (#173): its target as JSON,
/// null for none, as on every row from before targets existed. Kept so the
/// sheet still shows it after the app restarts mid-workout. A template's sets
/// need no column: they are already a JSON list in
/// `template_exercises.description`.
const addSetTarget = 'ALTER TABLE sets ADD COLUMN target TEXT';
