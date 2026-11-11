part of '../api.dart';

/// Device keys and key delivery for end-to-end encryption (heart-of-yours#555).
///
/// The server holds public keys and sealed items only: nothing here ever
/// carries a private key or words in the clear. A refusal is thrown whole, as
/// everywhere, so a caller branches on its `code` (`device_removed`,
/// `device_limit`, `rate_limited`, `queue_full`).
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
    final (json, code) = await post(
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
    return switch ((code, json)) {
      (200 || 201, Map json) => CryptoDevice.fromJson(json),
      _ => throw json,
    };
  }

  /// The account's own devices, or, with [userId], those of someone it has or
  /// had a connection with.
  Future<List<CryptoDevice>> getCryptoDevices({String? userId}) async {
    final (json, code) = await get(
      Router.cryptoDevices,
      // null rather than empty: an empty map still leaves a bare `?` on the path
      query: switch (userId) {
        final String id => {'userId': id},
        null => null,
      },
    );
    return switch ((code, json)) {
      (200, Map json) => CryptoDevices.fromJson(json).devices,
      _ => throw json,
    };
  }

  /// Removes one of the account's devices for good: it can't come back under
  /// its id.
  Future<void> removeCryptoDevice(String deviceId) async {
    final (json, code) = await delete(Router.cryptoDevice(deviceId));
    if (code != 204) throw json;
  }

  /// Adds single-use keys, by the name the device knows each by. Answers how
  /// many the server now holds for the device.
  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys) async {
    final (json, code) = await post(Router.oneTimeKeys(deviceId), body: {'keys': keys});
    return switch ((code, json)) {
      (200, Map json) => OneTimeKeyCount.fromJson(json).count,
      _ => throw json,
    };
  }

  /// How many single-use keys the server still holds for the device.
  Future<int> countOneTimeKeys(String deviceId) async {
    final (json, code) = await get(Router.oneTimeKeys(deviceId));
    return switch ((code, json)) {
      (200, Map json) => OneTimeKeyCount.fromJson(json).count,
      _ => throw json,
    };
  }

  Future<void> replaceFallbackKey(String deviceId, String key) async {
    final (json, code) = await put(Router.fallbackKey(deviceId), body: {'key': key});
    if (code != 204) throw json;
  }

  /// Takes one single-use key from each of [userId]'s devices, or the fallback
  /// key of a device that has none left.
  Future<List<CryptoDevice>> claimKeys(String userId) async {
    final (json, code) = await post(Router.keyClaims(userId), body: const {});
    return switch ((code, json)) {
      (200, Map json) => CryptoDevices.fromJson(json).devices,
      _ => throw json,
    };
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
  }) async {
    final (json, code) = await post(
      Router.keyQueue,
      body: {
        'id': id,
        'recipientDeviceId': recipientDeviceId,
        'senderDeviceId': senderDeviceId,
        'kind': kind,
        'content': content,
      },
    );
    if (code != 204) throw json;
  }

  /// Everything waiting for [deviceId] that it hasn't confirmed, in the
  /// server's order.
  Future<List<QueuedItem>> getKeyQueue(String deviceId) async {
    final (json, code) = await get(Router.keyQueue, query: {'deviceId': deviceId});
    return switch ((code, json)) {
      (200, Map json) => QueuedItems.fromJson(json).items,
      _ => throw json,
    };
  }

  /// Confirms items [deviceId] has taken: they stop being returned. In runs of
  /// the most the server takes at once.
  Future<void> confirmKeyItems(String deviceId, List<String> ids) async {
    final runs = Iterable.generate(
      (ids.length / _confirmable).ceil(),
      (index) => ids.skip(index * _confirmable).take(_confirmable).toList(),
    );
    for (final run in runs) {
      final (json, code) = await post(Router.keyQueueConfirmations, body: {'deviceId': deviceId, 'ids': run});
      if (code != 204) throw json;
    }
  }

  static const _confirmable = 500;
}
