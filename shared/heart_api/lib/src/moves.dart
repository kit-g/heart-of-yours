/// The exercise-history move endpoint's refusals (heart-api#140).
library;

/// Why the server refused a move.
enum ExerciseMoveRefusal {
  /// The source and the target are the same exercise.
  sameExercise,

  /// Either exercise is neither the library's nor the account's own: deleted
  /// since, or never there. The server does not say which of the two.
  unknownExercise,

  /// The target keeps its sets in other columns than the source, or one is
  /// assisted and the other not (heart-api#211): the source's sets would not
  /// read on it.
  incompatibleExercise,
}

/// The move endpoint's `400 same_exercise`, `404 unknown_exercise` or
/// `400 incompatible_exercise`.
class ExerciseMoveRefused implements Exception {
  final ExerciseMoveRefusal reason;

  const new(this.reason);

  @override
  String toString() => 'ExerciseMoveRefused(${reason.name})';
}
