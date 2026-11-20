part of '../api.dart';

/// Coaching's connections (#552): who is connected to whom, what a student
/// shares, pausing and ending, and the workouts hidden from every connection.
mixin _ConnectionRoutes on Requests {
  /// Every connection of the account, both directions, ended ones included.
  /// Read whole: a connection this build can't read is dropped, not fatal,
  /// since the server's roles and domains may grow ahead of the app.
  Future<List<Connection>> getConnections() async {
    final (json, code) = await get(Router.connections);
    return switch ((code, json)) {
      (200, {'connections': List l}) => _readable(l, Connection.fromJson),
      _ => throw _unreadable(code, 'GET', Router.connections),
    };
  }

  /// What the student of a coach connection opens to their coach beyond
  /// workouts since accepting. The list replaces the old one. Only the student
  /// may: the coach gets `403 forbidden`, thrown with its body like every refusal.
  ///
  /// By name, not by [ConnectionShare]: a share a newer server added is one
  /// this build must send back as it found it, or replacing the list revokes it.
  Future<Connection> setConnectionShares(String connectionId, Set<String> shares) async {
    final (json, code) = await put(
      Router.connectionShares(connectionId),
      body: {
        'shares': [...shares],
      },
    );
    return switch ((code, json)) {
      (200, Map json) => Connection.fromJson(json),
      _ => throw _unreadable(code, 'PUT', Router.connectionShares(connectionId)),
    };
  }

  /// Moves a connection to [status]: pausing a coach connection, and resuming
  /// it, which only its student may.
  Future<Connection> setConnectionStatus(String connectionId, ConnectionStatus status) async {
    final (json, code) = await put(Router.connection(connectionId), body: {'status': status.name});
    return switch ((code, json)) {
      (200, Map json) => Connection.fromJson(json),
      _ => throw _unreadable(code, 'PUT', Router.connection(connectionId)),
    };
  }

  /// Ends a connection for both people. The row stays, as `severed`.
  Future<void> endConnection(String connectionId) async {
    final (json, code) = await delete(Router.connection(connectionId));
    if (code != 204) throw _unreadable(code, 'DELETE', Router.connection(connectionId));
  }

  /// The workouts the account has hidden from every connection, and since when.
  Future<List<HiddenWorkout>> getHiddenWorkouts() async {
    final (json, code) = await get(Router.hiddenWorkouts);
    return switch ((code, json)) {
      (200, {'workouts': List l}) => [for (final each in l.cast<Map>()) HiddenWorkout.fromJson(each)],
      _ => throw _unreadable(code, 'GET', Router.hiddenWorkouts),
    };
  }

  /// Hides a workout from every connection, peers too. [at] is when the device
  /// says it happened.
  Future<void> hideWorkout(String workoutId, {DateTime? at}) async {
    final (json, code) = await put(
      Router.workoutHidden(workoutId),
      body: {'at': ?at?.toUtc().toIso8601String()},
    );
    if (code != 204) throw _unreadable(code, 'PUT', Router.workoutHidden(workoutId));
  }

  Future<void> unhideWorkout(String workoutId) async {
    final (json, code) = await delete(Router.workoutHidden(workoutId));
    if (code != 204) throw _unreadable(code, 'DELETE', Router.workoutHidden(workoutId));
  }
}
