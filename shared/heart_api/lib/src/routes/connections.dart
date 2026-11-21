part of '../api.dart';

/// Coaching's connections (#552): who is connected to whom, what a student
/// shares, pausing and ending, and the workouts hidden from every connection.
mixin _ConnectionRoutes on Requests {
  /// Every connection of the account, both directions, ended ones included.
  /// Read whole: a connection this build can't read is dropped, not fatal,
  /// since the server's roles and domains may grow ahead of the app.
  Future<List<Connection>> getConnections() async {
    final (json, _) = await get(Router.connections);
    return _readable(json['connections'] as List, Connection.fromJson);
  }

  /// What the student of a coach connection opens to their coach beyond
  /// workouts since accepting. The list replaces the old one. Only the student
  /// may: the coach gets the [ServerRefusal] `403 forbidden`.
  ///
  /// By name, not by [ConnectionShare]: a share a newer server added is one
  /// this build must send back as it found it, or replacing the list revokes it.
  Future<Connection> setConnectionShares(String connectionId, Set<String> shares) async {
    final (json, _) = await put(
      Router.connectionShares(connectionId),
      body: {
        'shares': [...shares],
      },
    );
    return Connection.fromJson(json);
  }

  /// Moves a connection to [status]: pausing a coach connection, and resuming
  /// it, which only its student may.
  Future<Connection> setConnectionStatus(String connectionId, ConnectionStatus status) async {
    final (json, _) = await put(Router.connection(connectionId), body: {'status': status.name});
    return Connection.fromJson(json);
  }

  /// Ends a connection for both people. The row stays, as `severed`.
  Future<void> endConnection(String connectionId) => delete(Router.connection(connectionId));

  /// The workouts the account has hidden from every connection, and since when.
  Future<List<HiddenWorkout>> getHiddenWorkouts() async {
    final (json, _) = await get(Router.hiddenWorkouts);
    return [for (final each in (json['workouts'] as List).cast<Map>()) HiddenWorkout.fromJson(each)];
  }

  /// Hides a workout from every connection, peers too. [at] is when the device
  /// says it happened.
  Future<void> hideWorkout(String workoutId, {DateTime? at}) {
    return put(
      Router.workoutHidden(workoutId),
      body: {'at': ?at?.toUtc().toIso8601String()},
    );
  }

  Future<void> unhideWorkout(String workoutId) => delete(Router.workoutHidden(workoutId));
}
