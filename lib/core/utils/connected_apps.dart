import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [ConnectedAppService] [ConnectedApps] wants (#448),
/// for the reason [RemoteApiTokens] exists: the app is where `heart_api` and
/// `heart_state` meet.
class RemoteConnectedApps implements ConnectedAppService {
  final Api _api;

  const new(this._api);

  @override
  Future<Iterable<ConnectedApp>> listConnectedApps() => _api.listConnectedApps();

  @override
  Future<void> disconnectApp(String grantId) => _api.disconnectApp(grantId);
}
