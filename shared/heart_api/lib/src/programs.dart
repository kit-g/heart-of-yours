/// The program routes' refusals (heart-api#86, `docs/2026-10-13.programs.md`
/// there).
library;

/// Why the server refused a program write, by the `code` it named.
enum ProgramRefusal {
  /// `400 invalid_rule`: a growth rule this server does not know, or out of
  /// range.
  invalidRule('invalid_rule'),

  /// `400 invalid_key`: a misspelled `source` or `constraint`.
  invalidKey('invalid_key'),

  /// `400 program_limit`: the account holds as many programs as it may,
  /// archived ones included.
  programLimit('program_limit'),

  /// `400 program_history_limit`: the program holds as many actions or bases
  /// as it may.
  programHistoryLimit('program_history_limit'),

  /// `404 program_not_found`: the program addressed is not the account's.
  programNotFound('program_not_found'),

  /// `404 unknown_program`: a template, action or base names a program the
  /// account does not have.
  unknownProgram('unknown_program'),

  /// `404 unknown_exercise`: a base names an exercise the account cannot see.
  unknownExercise('unknown_exercise'),

  /// `404 unknown_workout`: a base names a workout the account does not own.
  unknownWorkout('unknown_workout'),

  /// `404 unknown_action`: a base names an action the account does not own.
  unknownAction('unknown_action');

  /// The `code` on the wire.
  final String code;

  new(this.code);

  static ProgramRefusal? of(Object? body) {
    return switch (body) {
      {'code': final String code} => values.where((each) => each.code == code).firstOrNull,
      _ => null,
    };
  }
}

/// A program route answered with one of the codes [ProgramRefusal] names.
/// Asking again gets the same answer.
class ProgramRefused implements Exception {
  final ProgramRefusal reason;

  const new(this.reason);

  @override
  String toString() => 'ProgramRefused(${reason.code})';
}
