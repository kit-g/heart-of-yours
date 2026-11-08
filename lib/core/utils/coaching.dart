import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [CoachingService] [Coaching] wants (#552, #566), for
/// the reason [RemoteApiTokens] exists: the interface is the state package's
/// view of a few routes, and the app is where `heart_api` and `heart_state`
/// meet.
class RemoteCoaching implements CoachingService {
  final Api _api;

  const new(this._api);

  @override
  Future<List<Connection>> getConnections() => _api.getConnections();

  @override
  Future<Connection> setConnectionShares(String connectionKey, Set<ConnectionShare> shares) {
    return _api.setConnectionShares(connectionKey, shares);
  }

  @override
  Future<Connection> setConnectionStatus(String connectionKey, ConnectionStatus status) {
    return _api.setConnectionStatus(connectionKey, status);
  }

  @override
  Future<void> endConnection(String connectionKey) => _api.endConnection(connectionKey);

  @override
  Future<List<HiddenWorkout>> getHiddenWorkouts() => _api.getHiddenWorkouts();

  @override
  Future<void> hideWorkout(String workoutId, {DateTime? at}) => _api.hideWorkout(workoutId, at: at);

  @override
  Future<void> unhideWorkout(String workoutId) => _api.unhideWorkout(workoutId);
}
