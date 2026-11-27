part of '../../heart_db.dart';

/// An own exercise's edit the account has not had yet (#616): made with the
/// server out of reach, kept on the device, and sent by the next sync of the
/// account's own exercises. Until then that sync leaves the row alone.
///
/// 0 for nothing owed, 1 for an edit, 2 for an edit that renamed: only a
/// rename may send the name, or it would undo one made on another device.
///
/// A column of its own, outside the model: `storeExercises` builds its write
/// from the model's keys, so storing an exercise never touches it.
const addExerciseEditUnsent = 'ALTER TABLE exercises ADD COLUMN edit_unsent INTEGER NOT NULL DEFAULT 0';
