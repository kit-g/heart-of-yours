import 'package:heart_models/heart_models.dart';

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
