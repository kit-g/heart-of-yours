part of '../../heart_db.dart';

/// A program a coach sent (#557): who sent it, by name as the server gives
/// it, and, while the student is on something else, since when it has waited
/// to be started. Kept whatever the coaching switches say (`docs/opt-in.md`).
const addProgramCoachId = 'ALTER TABLE programs ADD COLUMN coach_id TEXT';
const addProgramCoachName = 'ALTER TABLE programs ADD COLUMN coach_name TEXT';
const addProgramWaitingSince = 'ALTER TABLE programs ADD COLUMN waiting_since TEXT';
