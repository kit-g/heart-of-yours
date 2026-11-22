part of '../api.dart';

/// Device keys and key delivery for end-to-end encryption (heart-of-yours#555).
///
/// The server holds public keys and sealed items only: nothing here ever
/// carries a private key or words in the clear. A refusal is a
/// [ServerRefusal], as everywhere, so a caller branches on its `code`
/// (`device_removed`, `device_limit`, `rate_limited`, `queue_full`).
/// The most devices one claim may name (heart-api#424).
const _claimLimit = 10;

mixin _KeyRoutes on Requests {
  /// Publishes this device's identity, once: a device's id is its own, and
  /// publishing it again answers what is there. [signature] and [vouchedBy]
  /// travel together or not at all.
  Future<CryptoDevice> publishCryptoDevice({
    required String id,
    required String identityKey,
    required String signingKey,
    required String fallbackKey,
    ({String signature, String vouchedBy})? vouch,
  }) async {
    final (json, _) = await post(
      Router.cryptoDevices,
      body: {
        'id': id,
        'identityKey': identityKey,
        'signingKey': signingKey,
        'fallbackKey': fallbackKey,
        'signature': ?vouch?.signature,
        'vouchedBy': ?vouch?.vouchedBy,
      },
    );
    return CryptoDevice.fromJson(json);
  }

  /// The account's own devices, or, with [userId], those of someone it has or
  /// had a connection with.
  Future<List<CryptoDevice>> getCryptoDevices({String? userId}) async {
    final (json, _) = await get(
      Router.cryptoDevices,
      // null rather than empty: an empty map still leaves a bare `?` on the path
      query: switch (userId) {
        final String id => {'userId': id},
        null => null,
      },
    );
    return CryptoDevices.fromJson(json).devices;
  }

  /// Vouches for [deviceId], one of the account's devices that already
  /// published: [vouchedBy], another of its devices in use, signed its keys.
  /// Answers the device. A device is vouched for once: the same vouch again
  /// answers it as it is, and a different one is refused (`already_vouched`).
  Future<CryptoDevice> vouchForCryptoDevice(
    String deviceId, {
    required String vouchedBy,
    required String signature,
  }) async {
    final (json, _) = await put(
      Router.cryptoDeviceVouch(deviceId),
      body: {'vouchedBy': vouchedBy, 'signature': signature},
    );
    return CryptoDevice.fromJson(json);
  }

  /// Removes one of the account's devices for good: it can't come back under
  /// its id.
  Future<void> removeCryptoDevice(String deviceId) => delete(Router.cryptoDevice(deviceId));

  /// Adds single-use keys, by the name the device knows each by. Answers how
  /// many the server now holds for the device.
  ///
  /// They travel as a list of `{id, key}`, never as a map of id to key: an id
  /// would be a field name, and the server refuses a body whose field names
  /// read like health data, which a random id can (heart-api#420).
  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys) async {
    final (json, _) = await post(
      Router.oneTimeKeys(deviceId),
      body: {
        'keys': [
          for (final MapEntry(:key, :value) in keys.entries) {'id': key, 'key': value},
        ],
      },
    );
    return OneTimeKeyCount.fromJson(json).count;
  }

  /// How many single-use keys the server still holds for the device.
  Future<int> countOneTimeKeys(String deviceId) async {
    final (json, _) = await get(Router.oneTimeKeys(deviceId));
    return OneTimeKeyCount.fromJson(json).count;
  }

  Future<void> replaceFallbackKey(String deviceId, String key) {
    return put(Router.fallbackKey(deviceId), body: {'key': key});
  }

  /// Takes one single-use key from each of [userId]'s devices, or the fallback
  /// key of a device that has none left. [deviceIds], one to ten of them,
  /// claims from those devices alone (heart-api#424); one that isn't theirs, or
  /// was removed, is left out of the answer.
  Future<List<CryptoDevice>> claimKeys(String userId, {List<String>? deviceIds}) async {
    if (deviceIds case final ids? when ids.isEmpty || ids.length > _claimLimit) {
      throw ArgumentError.value(ids.length, 'deviceIds', 'one to $_claimLimit devices a claim');
    }
    final (json, _) = await post(Router.keyClaims(userId), body: {'deviceIds': ?deviceIds});
    return CryptoDevices.fromJson(json).devices;
  }

  /// Sends one sealed item to one device. [id] is the sender's, so a retry
  /// delivers once. The server keeps the order of items only when the sender
  /// waits for each answer before sending the next.
  Future<void> enqueueKeyItem({
    required String id,
    required String recipientDeviceId,
    required String senderDeviceId,
    required String kind,
    required String content,
  }) {
    return post(
      Router.keyQueue,
      body: {
        'id': id,
        'recipientDeviceId': recipientDeviceId,
        'senderDeviceId': senderDeviceId,
        'kind': kind,
        'content': content,
      },
    );
  }

  /// Everything waiting for [deviceId] that it hasn't confirmed, in the
  /// server's order.
  Future<List<QueuedItem>> getKeyQueue(String deviceId) async {
    final (json, _) = await get(Router.keyQueue, query: {'deviceId': deviceId});
    return QueuedItems.fromJson(json).items;
  }

  /// Confirms items [deviceId] has taken: they stop being returned. In runs of
  /// the most the server takes at once.
  Future<void> confirmKeyItems(String deviceId, List<String> ids) async {
    final runs = Iterable.generate(
      (ids.length / _confirmable).ceil(),
      (index) => ids.skip(index * _confirmable).take(_confirmable).toList(),
    );
    for (final run in runs) {
      await post(Router.keyQueueConfirmations, body: {'deviceId': deviceId, 'ids': run});
    }
  }

  static const _confirmable = 500;
}
