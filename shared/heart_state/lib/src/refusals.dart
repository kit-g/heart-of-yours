import 'package:network_utils/network_utils.dart' show NetworkException;

/// How a notifier reads a failed call (#681). Every failure the server sent
/// back is a [NetworkException]; only some of them are the server's last word.
/// A bare `502` or an HTML error page, a throttle, or a server error says
/// nothing about the request, and is treated like no answer at all: asked
/// again later, never dropped for good.
extension Refusals on NetworkException {
  /// The server's own answer, one that asking again gets again: a body, under
  /// a status that is not a passing one (408, 425, 429 and 5xx).
  bool get isAnswered => !isTransient && body != null;

  /// An answer that names why it refused, as a `code`: the request itself is
  /// what has to change.
  bool get isRefusal => isAnswered && body?['code'] is String;
}
