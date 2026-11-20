import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:heart_models/heart_models.dart' hide PreSignedUrl;
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

import 'imports.dart';
import 'moves.dart';
import 'programs.dart';
import 'renames.dart';

part 'routes/accounts.dart';
part 'routes/workouts.dart';
part 'routes/exercises.dart';
part 'routes/programs.dart';
part 'routes/anomalies.dart';
part 'routes/goals.dart';
part 'routes/templates.dart';
part 'routes/connections.dart';
part 'routes/invitations.dart';
part 'routes/roster.dart';
part 'routes/library.dart';
part 'routes/push.dart';
part 'routes/keys.dart';
part 'routes/threads.dart';
part 'routes/notes.dart';
part 'routes/naming.dart';
part 'router.dart';

class Api
    with
        Requests,
        _ExerciseNaming,
        _AccountRoutes,
        _WorkoutRoutes,
        _ExerciseRoutes,
        _ProgramRoutes,
        _AnomalyRoutes,
        _GoalRoutes,
        _TemplateRoutes,
        _ConnectionRoutes,
        _InvitationRoutes,
        _RosterRoutes,
        _LibraryRoutes,
        _PushRoutes,
        _KeyRoutes,
        _ThreadRoutes,
        _NoteRoutes
    implements
        AccountService,
        AnomalyService,
        ApiTemplateFolderService,
        FeedbackService,
        GoalService,
        HeaderAuthenticatedService,
        RemoteExerciseService,
        RemoteTemplateService,
        RemoteWorkoutService {
  @override
  late String gateway;

  static final Api instance = Api._();

  @override
  Map<String, String>? defaultHeaders;

  new _();

  factory({
    required String gateway,
    http.Client? client,
    Response Function(Json)? onUnauthorized,
    Response Function(Json)? onUpgradeRequired,
  }) {
    instance
      ..gateway = gateway
      ..client = client
      ..onUnauthorized = onUnauthorized
      ..onUpgradeRequired = onUpgradeRequired;
    return instance;
  }

  @override
  http.Client? client;

  /// A refusal arrives as a [NetworkException] carrying the status, the verb,
  /// the path and the body, before any route sees it (#681). A route reads
  /// only what it can use, and names the refusals it has a type for with
  /// [_refused]; the rest reach the caller as they came, and Sentry as one
  /// issue per status and endpoint, never with the body in the title.
  @override
  bool get throwsOnFailure => true;

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  // Every verb runs through [_tripwire]: the one refusal that must never come
  // back is caught before any caller can act on it.

  @override
  Future<Response> get(String endpoint, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return super.get(endpoint, headers: headers, query: query).catchError(_tripwire);
  }

  @override
  Future<Response> post(String endpoint, {Map<String, String>? headers, Json? body, Map<String, dynamic>? query}) {
    return super.post(endpoint, headers: headers, body: body, query: query).catchError(_tripwire);
  }

  @override
  Future<Response> put(String endpoint, {Map<String, String>? headers, Json? body}) {
    return super.put(endpoint, headers: headers, body: body).catchError(_tripwire);
  }

  @override
  Future<Response> patch(String endpoint, {Map<String, String>? headers, Json? body}) {
    return super.patch(endpoint, headers: headers, body: body).catchError(_tripwire);
  }

  @override
  Future<Response> delete(String endpoint, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return super.delete(endpoint, headers: headers, query: query).catchError(_tripwire);
  }

  /// The server refused the token because it belongs to an anonymous
  /// session (heart-of-yours#91). That token never has business on the wire —
  /// `RemoteAccess` closes every leg while the session is anonymous — so this
  /// is not a failure to retry but a gate that failed, and it is thrown as its
  /// own type so it reaches Sentry under a name rather than as a body map.
  static Never _tripwire(Object error, StackTrace stacktrace) {
    return switch (error) {
      NetworkException(statusCode: 403, body: {'code': 'anonymous_account'}) => throw const AnonymousSessionRejected(),
      _ => Error.throwWithStackTrace(error, stacktrace),
    };
  }

  @override
  void reauthenticate(String sessionToken) {
    // Re-apply the scheme. Callers hand over a raw provider token (see
    // `onReauthenticate` in `main.dart`, which passes Firebase's id token
    // straight through), while the header this replaces was built as
    // `Bearer <token>` by `headers()`.
    //
    // Dropping the prefix does not read as unauthenticated — the gateway
    // rejects the header outright, with a *plain-text* body. That body then
    // fails to parse, so the caller saw a FormatException from deep inside
    // jsonDecode rather than a 401, on whichever request happened to be in
    // flight when the token expired. [isAuthenticated] asserts the same shape.
    instance.defaultHeaders?['Authorization'] = switch (sessionToken.startsWith('Bearer ')) {
      true => sessionToken,
      false => 'Bearer $sessionToken',
    };
  }

  /// Drops the session's token and keeps every other header.
  ///
  /// For the moment a session ends or changes hands: the token belongs to the
  /// account that signed in, and until the next one's lands, nothing should
  /// leave as that account (heart-of-yours#363). [isAuthenticated] reads
  /// false from here until then.
  void unauthenticate() {
    instance.defaultHeaders?.remove('Authorization');
  }

  /// Re-states what language the user speaks, mid-session.
  ///
  /// `Accept-Language` is set on every request via [defaultHeaders], built
  /// once at startup — but the device locale can change under a running app
  /// (in-app settings on iOS 13+, a returning foregrounded app on Android).
  /// Same single-key mutation shape as [reauthenticate].
  void localize(String languageTag) {
    instance.defaultHeaders?['Accept-Language'] = languageTag;
  }

  @override
  bool get isAuthenticated {
    return switch (defaultHeaders) {
      {'Authorization': String token} => switch (token.split(' ')) {
        ['Bearer', String token] when token.isNotEmpty => true,
        _ => false,
      },
      _ => false,
    };
  }
}

/// `201` made the row, `200` found it — by id, or by name for the two
/// resources with one. A refusal never gets here: it is the
/// [NetworkException] the `POST` to [endpoint] threw, code and all, so the
/// caller can tell one (`id_taken`, `goal_limit`) from an outage.
(Map, bool) _created(Response response, {required String endpoint}) {
  return switch (response) {
    (Map json, 201) => (json, true),
    (Map json, 200) => (json, false),
    (_, final code) => throw _unreadable(code, 'POST', endpoint),
  };
}

/// What a route throws for an answer it has no arm for. A refusal never gets
/// here — it is already the [NetworkException] the verb threw — so this is a
/// success in a shape the route cannot read: thrown as its status and
/// request, never its body, which is the account's own data and would title a
/// Sentry issue.
NetworkException _unreadable(int code, String method, String endpoint) {
  return NetworkException(statusCode: code, method: method, path: '/$endpoint');
}

/// [call], with the refusals a route has a meaning for turned into it by
/// [refused]: a value in their place, or a typed exception. [refused]
/// rethrows the rest as they came.
Future<T> _refused<T>(Future<T> call, FutureOr<T> Function(NetworkException failure) refused) {
  return call.catchError((Object failure) => refused(failure as NetworkException), test: (e) => e is NetworkException);
}

/// [call]'s answer, a refusal included, for the routes that have always read
/// one as an answer — "no link", "nothing to show", `false` — and whose
/// callers were written for that rather than for an exception.
Future<Response> _lenient(Future<Response> call) => _refused(call, _asAnswer);

/// [call]'s answer, a refusal with [status] included, for a route with a
/// meaning for that one: a `404` that is "no such thing", answered as null.
Future<Response> _answering(Future<Response> call, int status) {
  return _refused(call, (failure) => failure.statusCode == status ? _asAnswer(failure) : throw failure);
}

Response _asAnswer(NetworkException failure) => (<String, dynamic>{...?failure.body}, failure.statusCode);

/// [body] with its `id` only when it is one the server will take.
///
/// Templates minted before heart-of-yours#96 carry a timestamp for an id;
/// the server validates the shape and answers a `400` to anything that is
/// not a v7 uuid, so such an id is left off and the server mints one. The
/// caller reconciles the local row with whatever comes back, as it always
/// has for templates.
Map<String, dynamic> _withClientId(Map<String, dynamic> body) {
  return switch (body['id']) {
    String id when isUuidV7(id) => body,
    _ => body..remove('id'),
  };
}

/// An anonymous session's token reached the server, which answered `403
/// anonymous_account`. The remote leg is meant to be closed for the whole of
/// an anonymous session, so this is a tripwire: reported, never retried.
class AnonymousSessionRejected implements Exception {
  const new();

  @override
  String toString() => 'AnonymousSessionRejected: an anonymous token reached heart-api';
}

/// A page's query: none at all for the first, since an empty map would still
/// put a bare `?` on the URL.
Map<String, dynamic>? _cursor(String? cursor) {
  return switch (cursor) {
    final String cursor => {'cursor': cursor},
    null => null,
  };
}

/// The items of a list response this build can read, in order.
///
/// The server moves ahead of the apps in the stores: a value this build has
/// never heard of (a category, a set type, a goal metric) makes one item
/// unreadable, and that must cost the item, not the response. The rest is
/// still worth having; what was skipped stays on the server, and the update
/// that can read it picks it up.
///
/// Only for lists the app merges into its local copy. One that replaces a
/// local slice is read whole or not at all, because a skipped item there
/// would delete its local copy.
List<T> _readable<T>(List raw, T Function(Map json) parse) {
  return [
    for (final each in raw)
      if (each is Map)
        if (_tryRead(() => parse(each)) case final T item) item,
  ];
}

T? _tryRead<T>(T Function() parse) {
  try {
    return parse();
  } catch (_) {
    return null;
  }
}
