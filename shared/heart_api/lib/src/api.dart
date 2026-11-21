import 'dart:convert';
import 'dart:typed_data';

import 'package:heart_models/heart_models.dart' hide PreSignedUrl;
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

import 'imports.dart';
import 'moves.dart';
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

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  /// Every failed request is thrown, so a route reads only what succeeded.
  /// What it is thrown as is [failure]'s to say, in one place.
  @override
  bool get throwsOnFailure => true;

  /// A failure as the callers read it (#681), the order mattering: the three
  /// answers the app acts on everywhere come first, before anything is read as
  /// a refusal. Then a named 4xx is a [ServerRefusal]; anything else, a 5xx, a
  /// gateway's page or a body without a `code`, stays a [NetworkException],
  /// its body dropped, since it can echo what the account sent. A 2xx that
  /// could not be read is an [UnreadableAnswer].
  ///
  /// The upgrade prompt still fires on a 426: `onUpgradeRequired` has run by
  /// the time this is asked.
  @override
  Exception failure(NetworkException exception) {
    final NetworkException(:statusCode, :method, :path, :body) = exception;
    return switch ((statusCode, body)) {
      (426, _) => UpgradeRequired(),
      (400, {'code': 'ACCOUNT_DELETED'}) => AccountDeleted(),
      (403, {'code': 'anonymous_account'}) => AnonymousSessionRejected(),
      _ => switch (ServerRefusal.tryParse(
        status: statusCode,
        method: method ?? '',
        route: exception.endpoint ?? '',
        body: body,
      )) {
        final ServerRefusal refusal => refusal,
        null when statusCode >= 200 && statusCode < 300 => UnreadableAnswer(
          statusCode: statusCode,
          method: method,
          path: path,
        ),
        null => NetworkException(statusCode: statusCode, method: method, path: path),
      },
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
/// resources with one. A refusal never gets here: [Api.failure] threw it.
(Map, bool) _created(Response response) {
  return switch (response) {
    (final json, 201) => (json, true),
    (final json, _) => (json, false),
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

/// A 2xx whose body could not be read: not JSON, or JSON but not an object.
///
/// A [NetworkException], so it is reported and grouped like any other failed
/// request, by status and route and never the body; and a [FormatException],
/// which is what a caller with no HTTP types in sight already reads as "an
/// answer this build cannot read, and asking again gets the same one".
class UnreadableAnswer extends NetworkException implements FormatException {
  const new({required super.statusCode, super.method, super.path});

  @override
  String get message => 'an answer this build cannot read';

  @override
  int? get offset => null;

  @override
  dynamic get source => null;
}

/// An anonymous session's token reached the server, which answered `403
/// anonymous_account`. The remote leg is meant to be closed for the whole of
/// an anonymous session, so this is a tripwire: reported, never retried.
///
/// Not const: the client records which failure each one came from on the
/// instance, and a const one would be every one of them.
class AnonymousSessionRejected implements Exception {
  new();

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
