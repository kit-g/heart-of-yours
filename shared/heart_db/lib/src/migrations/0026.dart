part of '../../heart_db.dart';

/// What a goal counting sets or sessions is about when it isn't one exercise
/// (#344, heart-api#196): a movement pattern key from the library, or a
/// muscle group. Null on every goal from before, and on every goal of another
/// metric; at most one of these and `exercise_id` is set.
const addGoalPattern = 'ALTER TABLE goals ADD COLUMN pattern TEXT';
const addGoalMuscle = 'ALTER TABLE goals ADD COLUMN muscle TEXT';
