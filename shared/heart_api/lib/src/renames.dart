/// The exercise edit endpoint's refusal of a rename (heart-api#429).
library;

/// `409 name_taken`: another of the account's own exercises already has the
/// name an edit asked for. The library's names don't count — an own exercise
/// may share one (#529).
class ExerciseNameTaken implements Exception {
  const new();

  @override
  String toString() => 'ExerciseNameTaken';
}
