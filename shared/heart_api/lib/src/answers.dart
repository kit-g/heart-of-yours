part of 'api.dart';

/// The server answered, and the answer was not one the route could use: the
/// body it sent, and the request it answered (#681).
///
/// Both at once, because the two halves have different readers. `heart_state`
/// reads a refusal's `code` off what a route throws (`id_taken`,
/// `goal_limit`, `thread_closed`), and tells an answer from a dropped
/// connection by `error is Map` (`Upsync.reachedServer`, #113); it cannot see
/// this package's types, so to it this is the [Map] a route always threw.
/// Everything that reports a failure sees a [NetworkException], which
/// `reportToSentry` gives one issue per status and endpoint: thrown as a bare
/// map, an outage grouped by stack into an issue per call site, each titled
/// with the body.
///
/// The body stays in memory for the caller and never reaches a report: Sentry
/// takes an exception's type and its [toString], and that names the status,
/// the verb and the templated path only.
///
/// Every verb wraps a failure in one (see `Api._send`), so a route that throws
/// what came back throws this, whatever status it did not name.
class _ServerAnswer extends NetworkException with MapMixin<String, dynamic> {
  new(Json body, {required super.statusCode, super.method, super.path}) : super(body: body);

  Json get _body => body as Json;

  @override
  dynamic operator [](Object? key) => _body[key];

  @override
  void operator []=(String key, dynamic value) => _body[key] = value;

  @override
  Iterable<String> get keys => _body.keys;

  @override
  int get length => _body.length;

  @override
  bool containsKey(Object? key) => _body.containsKey(key);

  @override
  dynamic remove(Object? key) => _body.remove(key);

  @override
  void clear() => _body.clear();

  /// [NetworkException.endpoint], with a workout id minted before #96 — a
  /// start time, `2024-03-05T18:22:11.123Z` — templated too. Left in, it split
  /// one endpoint's failures across an issue per workout, and put when the
  /// user trained into the issue's title.
  @override
  String? get endpoint {
    return super.endpoint?.split('/').map((each) => _timestamp.hasMatch(each) ? '{id}' : each).join('/');
  }

  static final _timestamp = RegExp(r'^\d{4}-\d{2}-\d{2}T');

  // Not `super.toString()`: here that is the mixin's, which prints the body.
  @override
  String toString() {
    return switch ([method, endpoint].nonNulls.join(' ')) {
      '' => 'NetworkException($statusCode)',
      final request => 'NetworkException($statusCode $request)',
    };
  }
}

/// The request each success answered, for a route that cannot read it: only
/// the verb knows the request, and a route holds nothing but the body.
final _requests = Expando<({String method, String path})>('request');

/// What a route throws for an answer it has no arm for.
///
/// A failure already is the [_ServerAnswer] that names its request. What is
/// left is a success in a shape the route cannot read, thrown as an empty
/// answer naming its request: still a server's answer to `heart_state`, and
/// grouped by endpoint like any other, but without the body, which is the
/// account's own data and, thrown as it came, would title a Sentry issue.
NetworkException _unexpected(Json json, int code) {
  return switch (json) {
    _ServerAnswer answer => answer,
    _ => switch (_requests[json]) {
      (:final method, :final path) => _ServerAnswer({}, statusCode: code, method: method, path: path),
      null => _ServerAnswer({}, statusCode: code),
    },
  };
}
