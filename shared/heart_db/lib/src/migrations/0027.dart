part of '../../heart_db.dart';

/// A stages rule's step (heart-api#256, #350): the exercise it moved, the
/// occurrence whose rule it was when the program keeps one per slot, and the
/// stage it moved to, from 0. Null on every action of another kind.
const addProgramActionExercise = 'ALTER TABLE program_actions ADD COLUMN exercise_id TEXT';
const addProgramActionSlot = 'ALTER TABLE program_actions ADD COLUMN slot TEXT';
const addProgramActionStage = 'ALTER TABLE program_actions ADD COLUMN stage INTEGER';
