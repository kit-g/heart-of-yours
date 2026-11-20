part of 'api.dart';

/// The server answered, and the answer was not a success: the body it sent,
/// and the request it answered (#681).
///
/// Both at once, because the two halves have different readers. `heart_state`
/// reads a refusal's `code` off what a route throws (`id_taken`,
/// `goal_limit`, `thread_closed`) and cannot see this package's types, so to
/// it this is the [Map] a route always threw. Everything that reports a
/// failure sees a [NetworkException], which `reportToSentry` gives one issue
/// per status and endpoint: thrown as a bare map, an outage grouped by stack
/// into an issue per call site, each titled with the body.
///
/// The body stays in memory for the caller and never reaches a report: Sentry
/// takes an exception's type and its [toString], and that names the status,
/// the verb and the templated path only.
///
/// Every verb wraps a non-2xx answer in one (see `Api._answered`), so a route
/// that throws what came back throws this, whatever status it did not name.
class _ServerAnswer extends NetworkException with MapMixin<String, dynamic> {
  final Json _body;

  new(Json body, {required super.statusCode, required String super.method, required String super.path})
    : _body = body,
      super(body: body);

  @override
  dynamic operator [](Object? key) => _body[key];

  @override
  void operator []=(String key, dynamic value) => _body[key] = value;

  @override
  Iterable<String> get keys => _body.keys;

  @override
  dynamic remove(Object? key) => _body.remove(key);

  @override
  void clear() => _body.clear();

  // The mixin's would print the body, and `super` here is the mixin's: the
  // request's own wording is rebuilt instead.
  @override
  String toString() => NetworkException(statusCode: statusCode, method: method, path: path).toString();
}

/// What a route throws for an answer it has no arm for.
///
/// A failure is already the [_ServerAnswer] that names its request. What is
/// left is a success in a shape the route cannot read, thrown as its status
/// alone: a success body is the account's own data, and thrown as it came it
/// would be the title of a Sentry issue.
NetworkException _unexpected(Json json, int code) {
  return switch (json) {
    _ServerAnswer answer => answer,
    _ => NetworkException(statusCode: code),
  };
}
