import 'package:heart_api/heart_api.dart' show ExerciseNameTaken, NetworkException, originOf;
import 'package:heart_state/heart_state.dart' show RemoteAccess, RemoteFailure;

/// What a failure [Api] threw says about asking again (#681), the one reading
/// [RemoteAccess] hands every notifier: by the response it came from, when
/// there was one. `heart_state` sees no HTTP types, so this is where a 5xx is
/// told from a 413 and both from no answer at all.
RemoteFailure remoteFailure(Object error) {
  // the client's own name for a 409, thrown in the refusal's place with
  // nothing to trace it back by (#616): an answer, and never one to wait out
  if (error is ExerciseNameTaken) return .answered;
  return switch (originOf(error)) {
    NetworkException(statusCode: 404) => .gone,
    NetworkException(:final isTransient) when isTransient => .transient,
    // a refusal, a gateway's 4xx with no code, a 401 a reauth could not
    // mend, a forced upgrade, a 2xx this build could not read
    NetworkException() => .answered,
    // nothing answered, or not a request at all: read by its type
    null => RemoteAccess.byType(error),
  };
}
