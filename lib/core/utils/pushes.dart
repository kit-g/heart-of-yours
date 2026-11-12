import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RemotePushService] [Pushes] wants (#567, #554), for
/// the reason [RemoteCoaching] exists: the interface is the state package's
/// view of a few routes, and the app is where `heart_api` and `heart_state`
/// meet.
class RemotePushes implements RemotePushService {
  final Api _api;

  const new(this._api);

  @override
  Future<void> registerDevice({required DevicePlatform platform, required String token, int? utcOffsetMinutes}) {
    return _api.registerDevice(platform: platform, token: token, utcOffsetMinutes: utcOffsetMinutes);
  }

  @override
  Future<void> unregisterDevice(String token) => _api.unregisterDevice(token);

  @override
  Future<PushSettings> getPushSettings() => _api.getPushSettings();

  @override
  Future<void> setPushSetting(String topic, String delivery, {String? connectionId}) {
    return _api.setPushSetting(topic, delivery, connectionId: connectionId);
  }

  @override
  Future<void> clearPushSetting(String topic, {String? connectionId}) {
    return _api.clearPushSetting(topic, connectionId: connectionId);
  }
}
