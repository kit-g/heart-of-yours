import 'package:heart_models/heart_models.dart';

/// The codes the program routes refuse a write or read with (heart-api#86):
/// a rule, key or plan the server doesn't take, a cap reached, or a reference
/// to a row the account doesn't have. Asking again gets the same answer.
///
/// One list for every caller that has to tell a final refusal from a failure
/// worth retrying, so the callers cannot drift apart.
const programRefusals = {
  'invalid_rule',
  'invalid_key',
  'invalid_deload',
  'invalid_phase',
  'invalid_plan',
  'invalid_test',
  'invalid_target',
  'program_limit',
  'program_history_limit',
  'program_not_found',
  'unknown_program',
  'unknown_exercise',
  'unknown_workout',
  'unknown_action',
  'skip_limit',
};

/// What a [ServerRefusal] says about asking again (#681).
extension RefusalReading on ServerRefusal {
  /// The server's own throttle: `429 rate_limited`, with a `retryAfter`. A
  /// refusal of the moment rather than of the request, so it is asked again
  /// later and never recorded as final.
  bool get isThrottle => status == 429;

  /// The server's sentence for the refusal, under either of the keys it uses.
  String? get reason {
    return switch (details) {
      {'reason': final String reason} => reason,
      {'message': final String message} => message,
      _ => null,
    };
  }

  /// How long the server asked to be left alone, when it said.
  Duration? get retryAfter {
    return switch (details['retryAfter']) {
      final num seconds => Duration(seconds: seconds.ceil()),
      _ => null,
    };
  }
}
