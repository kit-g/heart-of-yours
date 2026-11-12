part of '../device_keys.dart';

/// This device's own keys: made once, published, and kept stocked.
extension _OwnKeys on DeviceKeys {
  /// The most single-use keys a device holds, the server's and the library's
  /// limit alike.
  static const _oneTimeKeys = Sealbox.maxOneTimeKeys;

  /// Below this many on the server, more are made.
  static const _lowOneTimeKeys = _oneTimeKeys ~/ 2;

  /// How long a fallback key serves before a new one replaces it.
  static const _fallbackLife = Duration(days: 7);

  /// This device's keys for [run]'s account, made the first time. Needs no
  /// network and no turn in the queue: whoever asks while they are being read
  /// or made waits for that, and nothing else.
  Future<_Device> _local(_Run run) async {
    if (run.device case final _Device device) return device;
    await (run.loading ??= _load(run).whenComplete(() => run.loading = null));
    return run.device!;
  }

  Future<void> _load(_Run run) async {
    final storageKey = await run.read('storage') ?? await _newStorageKey(run);
    final box = run.box = Sealbox(storageKey);
    final device = await run.storedDevice() ?? await _create(run, box);
    run.check();
    run.device = device;
    if (run.status == .off) {
      run.status = switch (device.published) {
        true => .published,
        false => .local,
      };
    }
  }

  Future<String> _newStorageKey(_Run run) async {
    final random = Random.secure();
    final key = base64.encode(List.generate(32, (_) => random.nextInt(256)));
    await run.write('storage', key);
    return key;
  }

  Future<_Device> _create(_Run run, Sealbox box) async {
    final made = _guard(() => box.createAccount(oneTimeKeys: _oneTimeKeys));
    final device = _Device(
      id: _newId(),
      account: made.account,
      published: false,
      pending: {for (final each in made.oneTimeKeys) each.id: each.key},
      fallbackKey: made.fallbackKey.key,
      fallbackAt: _now(),
    );
    await run.saveDevice(device);
    return device;
  }

  Future<void> _publish(_Run run) async {
    final device = await _local(run);
    if (device.published) return;
    final keys = run.sealbox.accountKeys(device.account);
    try {
      await run.service.publishCryptoDevice(
        id: device.id,
        identityKey: keys.identityKey,
        signingKey: keys.signingKey,
        fallbackKey: device.fallbackKey,
      );
    } on Map catch (refusal) {
      // a device removed for good can't come back under its id: this phone
      // starts over as a new one, which takes the old one's place in one step
      if (refusal case {'code': 'device_removed'}) {
        await _create(run, run.sealbox);
        return _publish(run);
      }
      run.status = .failed;
      _changed(run);
      rethrow;
    }
    await run.saveDevice(device.copyWith(published: true));
    run.status = .published;
    _changed(run);
  }

  /// Keeps single-use keys on the server, and the fallback key fresh.
  Future<void> _restock(_Run run) async {
    var device = await _local(run);
    if (!device.published) return;
    final box = run.sealbox;

    // what was made and never reached the server goes first
    if (device.pending.isNotEmpty) {
      await run.service.addOneTimeKeys(device.id, device.pending);
      device = device.copyWith(pending: const {});
      await run.saveDevice(device);
    }

    final held = await run.service.countOneTimeKeys(device.id);
    if (held < _lowOneTimeKeys) {
      // the library keeps every key not yet spent, claimed or not, so it may
      // have less room than the server
      final room = _oneTimeKeys - box.accountKeys(device.account).storedOneTimeKeys;
      final count = min(_oneTimeKeys - held, room);
      if (count > 0) {
        final made = _guard(() => box.generateOneTimeKeys(device.account, count));
        device = device.copyWith(
          account: made.account,
          pending: {for (final each in made.oneTimeKeys) each.id: each.key},
        );
        await run.saveDevice(device);
        await run.service.addOneTimeKeys(device.id, device.pending);
        device = device.copyWith(pending: const {});
        await run.saveDevice(device);
      }
    }

    if (device.fallbackPending) {
      await run.service.replaceFallbackKey(device.id, device.fallbackKey);
      await run.saveDevice(device.copyWith(fallbackPending: false));
    } else if (_now().difference(device.fallbackAt) > _fallbackLife) {
      final rotated = _guard(() => box.rotateFallbackKey(device.account));
      device = device.copyWith(
        account: rotated.account,
        fallbackKey: rotated.fallbackKey.key,
        fallbackAt: _now(),
        fallbackPending: true,
      );
      await run.saveDevice(device);
      await run.service.replaceFallbackKey(device.id, rotated.fallbackKey.key);
      await run.saveDevice(device.copyWith(fallbackPending: false));
    }
  }
}

/// This device's own record: its id, its account sealed under the storage key,
/// and what it made that the server hasn't taken yet.
class _Device {
  final String id;
  final String account;
  final bool published;

  /// Single-use keys made and not yet on the server, by name.
  final Map<String, String> pending;

  final String fallbackKey;
  final DateTime fallbackAt;

  /// A new fallback key the server hasn't taken yet.
  final bool fallbackPending;

  const new({
    required this.id,
    required this.account,
    required this.published,
    required this.pending,
    required this.fallbackKey,
    required this.fallbackAt,
    this.fallbackPending = false,
  });

  _Device copyWith({
    String? account,
    bool? published,
    Map<String, String>? pending,
    String? fallbackKey,
    DateTime? fallbackAt,
    bool? fallbackPending,
  }) {
    return _Device(
      id: id,
      account: account ?? this.account,
      published: published ?? this.published,
      pending: pending ?? this.pending,
      fallbackKey: fallbackKey ?? this.fallbackKey,
      fallbackAt: fallbackAt ?? this.fallbackAt,
      fallbackPending: fallbackPending ?? this.fallbackPending,
    );
  }

  Map<String, Object> toMap() => {
    'id': id,
    'account': account,
    'published': published,
    'pending': pending,
    'fallbackKey': fallbackKey,
    'fallbackAt': fallbackAt.toUtc().toIso8601String(),
    'fallbackPending': fallbackPending,
  };

  static _Device? of(Map? json) {
    return switch (json) {
      {
        'id': final String id,
        'account': final String account,
        'published': final bool published,
        'pending': final Map pending,
        'fallbackKey': final String fallbackKey,
        'fallbackAt': final String fallbackAt,
        'fallbackPending': final bool fallbackPending,
      } =>
        _Device(
          id: id,
          account: account,
          published: published,
          pending: pending.cast<String, String>(),
          fallbackKey: fallbackKey,
          fallbackAt: DateTime.parse(fallbackAt),
          fallbackPending: fallbackPending,
        ),
      _ => null,
    };
  }
}
