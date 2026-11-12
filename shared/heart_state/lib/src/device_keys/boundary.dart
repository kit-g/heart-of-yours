part of '../device_keys.dart';

/// What the server does with device keys (heart-of-yours#555).
///
/// Defined here, like `RemotePushService`: the app's view of a few routes,
/// which it adapts `Api` onto.
abstract interface class RemoteKeyService {
  Future<CryptoDevice> publishCryptoDevice({
    required String id,
    required String identityKey,
    required String signingKey,
    required String fallbackKey,
    ({String signature, String vouchedBy})? vouch,
  });

  Future<List<CryptoDevice>> getCryptoDevices({String? userId});

  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys);

  Future<int> countOneTimeKeys(String deviceId);

  Future<void> replaceFallbackKey(String deviceId, String key);

  Future<List<CryptoDevice>> claimKeys(String userId);

  Future<void> enqueueKeyItem({
    required String id,
    required String recipientDeviceId,
    required String senderDeviceId,
    required String kind,
    required String content,
  });

  Future<List<QueuedItem>> getKeyQueue(String deviceId);

  Future<void> confirmKeyItems(String deviceId, List<String> ids);
}

/// Where a device keeps its keys: on this device only, out of every backup
/// and every transfer to a new phone (the Keychain's this-device-only class,
/// Android's Keystore). A phone restored from a backup would reuse keys it had
/// already used, so a restored phone has to start as a new device.
abstract interface class KeyVault {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
