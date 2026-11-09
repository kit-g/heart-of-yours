import 'dart:convert';
import 'dart:typed_data';

import 'package:heart_models/heart_models.dart' hide PreSignedUrl;
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

import 'imports.dart';
import 'moves.dart';
import 'programs.dart';

part 'routes/accounts.dart';
part 'routes/workouts.dart';
part 'routes/exercises.dart';
part 'routes/programs.dart';
part 'routes/anomalies.dart';
part 'routes/goals.dart';
part 'routes/templates.dart';
part 'routes/connections.dart';
part 'routes/invitations.dart';
part 'router.dart';

class Api
    with
        Requests,
        _AccountRoutes,
        _WorkoutRoutes,
        _ExerciseRoutes,
        _ProgramRoutes,
        _AnomalyRoutes,
        _GoalRoutes,
        _TemplateRoutes,
        _ConnectionRoutes,
        _InvitationRoutes
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

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  // Every verb runs through [_tripwire]: the one answer that must never come
  // back is caught before any caller can act on it.

  @override
  Future<Response> get(String endpoint, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return super.get(endpoint, headers: headers, query: query).then(_tripwire);
  }

  @override
  Future<Response> post(String endpoint, {Map<String, String>? headers, Json? body, Map<String, dynamic>? query}) {
    return super.post(endpoint, headers: headers, body: body, query: query).then(_tripwire);
  }

  @override
  Future<Response> put(String endpoint, {Map<String, String>? headers, Json? body}) {
    return super.put(endpoint, headers: headers, body: body).then(_tripwire);
  }

  @override
  Future<Response> patch(String endpoint, {Map<String, String>? headers, Json? body}) {
    return super.patch(endpoint, headers: headers, body: body).then(_tripwire);
  }

  @override
  Future<Response> delete(String endpoint, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return super.delete(endpoint, headers: headers, query: query).then(_tripwire);
  }

  /// The server refused the token because it belongs to an anonymous
  /// session (heart-of-yours#91). That token never has business on the wire —
  /// `RemoteAccess` closes every leg while the session is anonymous — so this
  /// is not a failure to retry but a gate that failed, and it is thrown as its
  /// own type so it reaches Sentry under a name rather than as a body map.
  static Response _tripwire(Response response) {
    return switch (response) {
      ({'code': 'anonymous_account'}, 403) => throw const AnonymousSessionRejected(),
      _ => response,
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
/// resources with one. Anything else is thrown whole, code and all, so the
/// caller can tell a refusal (`id_taken`, `goal_limit`) from an outage.
(Map, bool) _created((Map, int) response) {
  return switch (response) {
    (Map json, 201) => (json, true),
    (Map json, 200) => (json, false),
    (final json, _) => throw json,
  };
}

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
