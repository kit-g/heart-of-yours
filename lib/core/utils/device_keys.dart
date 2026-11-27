import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RemoteKeyService] [DeviceKeys] wants (#555), for the
/// reason [RemotePushes] exists: the interface is the state package's view of
/// a few routes, and the app is where `heart_api` and `heart_state` meet.
class RemoteDeviceKeys implements RemoteKeyService {
  final Api _api;

  const new(this._api);

  @override
  Future<CryptoDevice> publishCryptoDevice({
    required String id,
    required String identityKey,
    required String signingKey,
    required String fallbackKey,
    ({String signature, String vouchedBy})? vouch,
  }) {
    return _api.publishCryptoDevice(
      id: id,
      identityKey: identityKey,
      signingKey: signingKey,
      fallbackKey: fallbackKey,
      vouch: vouch,
    );
  }

  @override
  Future<List<CryptoDevice>> getCryptoDevices({String? userId}) => _api.getCryptoDevices(userId: userId);

  @override
  Future<CryptoDevice> vouchForCryptoDevice(String deviceId, {required String vouchedBy, required String signature}) {
    return _api.vouchForCryptoDevice(deviceId, vouchedBy: vouchedBy, signature: signature);
  }

  @override
  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys) => _api.addOneTimeKeys(deviceId, keys);

  @override
  Future<int> countOneTimeKeys(String deviceId) => _api.countOneTimeKeys(deviceId);

  @override
  Future<void> replaceFallbackKey(String deviceId, String key) => _api.replaceFallbackKey(deviceId, key);

  @override
  Future<List<CryptoDevice>> claimKeys(String userId, {List<String>? deviceIds}) {
    return _api.claimKeys(userId, deviceIds: deviceIds);
  }

  @override
  Future<void> enqueueKeyItem({
    required String id,
    required String recipientDeviceId,
    required String senderDeviceId,
    required String kind,
    required String content,
  }) {
    return _api.enqueueKeyItem(
      id: id,
      recipientDeviceId: recipientDeviceId,
      senderDeviceId: senderDeviceId,
      kind: kind,
      content: content,
    );
  }

  @override
  Future<List<QueuedItem>> getKeyQueue(String deviceId) => _api.getKeyQueue(deviceId);

  @override
  Future<void> confirmKeyItems(String deviceId, List<String> ids) => _api.confirmKeyItems(deviceId, ids);
}
