part of '../../heart_db.dart';

/// A plain set is stored as no type at all, as the server stores it and as
/// every set from before types existed already is. Builds between 15 and 16
/// wrote the word instead; this folds those rows into the one shape (#151).
const clearNormalSetType = "UPDATE sets SET set_type = NULL WHERE set_type = 'normal'";
