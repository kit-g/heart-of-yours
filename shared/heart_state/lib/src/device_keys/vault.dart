part of '../device_keys.dart';

/// One account's keys from a start until a stop or a sign-out: its slice of
/// the vault, what was read from it, and where it stands.
///
/// A stop ends the run. Whatever was queued in it and comes up later finds
/// [service] and [vault] closed, and stops there: nothing more is read,
/// written or sent for an account that is no longer the one running.
class _Run {
  final String userId;
  final RemoteKeyService _service;
  final KeyVault _vault;

  new(this.userId, this._service, this._vault);

  bool _over = false;

  /// This device's keys, once read or made.
  _Device? device;

  Sealbox? box;

  /// Reading or making the keys, while it is on its way: whoever asks in the
  /// meantime waits for the same one, so a device is made once.
  Future<void>? loading;

  DeviceKeysStatus status = .off;

  final peers = <String, Peer>{};

  /// When each thread last shared its keys with every device it knew of.
  final sharedAt = <String, DateTime>{};

  /// Each thread's shares, one after another.
  final sharing = <String, Future<void>>{};

  /// The note keys' turn: their record is read and written one step at a
  /// time, apart from the steps that wait on the network.
  Future<void> notesTail = Future.value();

  void end() => _over = true;

  /// Throws [_Stopped] once the run is over.
  void check() {
    if (_over) throw _Stopped();
  }

  RemoteKeyService get service {
    check();
    return _service;
  }

  KeyVault get vault {
    check();
    return _vault;
  }

  Sealbox get sealbox => box!;

  String _key(String name) => 'keys.$userId.$name';

  Future<String?> read(String name) => vault.read(_key(name));

  Future<void> write(String name, String value) => vault.write(_key(name), value);

  Future<void> forget(String name) => vault.delete(_key(name));

  Future<_Device?> storedDevice() async => _Device.of(_decode(await read('device')));

  Future<void> saveDevice(_Device device) async {
    await vault.write(_key('device'), jsonEncode(device.toMap()));
    this.device = device;
  }

  Future<_Session?> session(String deviceId) async {
    return switch (_decode(await read('session.$deviceId'))) {
      {'session': final String session, 'sessionId': final String sessionId, 'identityKey': final String identityKey} =>
        (session: session, sessionId: sessionId, identityKey: identityKey),
      _ => null,
    };
  }

  Future<void> saveSession(String deviceId, _Session session) {
    return vault.write(
      _key('session.$deviceId'),
      jsonEncode({'session': session.session, 'sessionId': session.sessionId, 'identityKey': session.identityKey}),
    );
  }

  Future<List<KeyDelivery>> inbox() async {
    return switch (_decode(await read('inbox'))) {
      {'items': final List items} => [...items.map(KeyDelivery.of).nonNulls],
      _ => [],
    };
  }

  Future<void> saveInbox(List<KeyDelivery> inbox) {
    return vault.write(
      _key('inbox'),
      jsonEncode({
        'items': [for (final each in inbox) each.toMap()],
      }),
    );
  }

  /// When this device first saw each of [userId]'s devices.
  Future<Map<String, DateTime?>> seen(String userId) async {
    return switch (_decode(await read('seen.$userId'))) {
      final Map seen => {
        for (final MapEntry(:key, :value) in seen.entries)
          '$key': switch (value) {
            final String at => DateTime.tryParse(at),
            _ => null,
          },
      },
      _ => {},
    };
  }

  Future<void> saveSeen(String userId, Map<String, DateTime?> seen) {
    return vault.write(
      _key('seen.$userId'),
      jsonEncode({for (final MapEntry(:key, :value) in seen.entries) key: value?.toUtc().toIso8601String()}),
    );
  }

  /// The account's devices this one compared a code with, each by the keys
  /// it had then: what this device trusts of its own besides itself.
  Future<Map<String, String>> compared() async {
    return switch (_decode(await read('compared'))) {
      final Map compared => {
        for (final MapEntry(:key, :value) in compared.entries)
          if (value case final String keys) '$key': keys,
      },
      _ => {},
    };
  }

  Future<void> saveCompared(String deviceId, String keys) async {
    await write('compared', jsonEncode({...await compared(), deviceId: keys}));
  }

  /// The devices this one compared a code with whose vouch didn't reach the
  /// server, each by the keys compared: tried again until it does, or until
  /// the server lists it vouched for by another.
  Future<Map<String, String>> owed() async {
    final owed = switch (_decode(await read('owed'))) {
      final Map owed => {
        for (final MapEntry(:key, :value) in owed.entries)
          if (value case final String keys) '$key': keys,
      },
      _ => <String, String>{},
    };
    owing
      ..clear()
      ..addAll(owed.keys);
    return owed;
  }

  Future<void> saveOwed(Map<String, String> owed) async {
    await write('owed', jsonEncode(owed));
    owing
      ..clear()
      ..addAll(owed.keys);
  }

  /// [owed]'s devices, as last read or written: what a screen asks without
  /// waiting on the vault.
  final owing = <String>{};

  /// The threads this device made a key for: what it shares again when one of
  /// the account's devices comes to be trusted.
  Future<Set<String>> threads() async {
    return switch (_decode(await read('threads'))) {
      {'ids': final List ids} => {for (final each in ids) '$each'},
      _ => {},
    };
  }

  Future<void> addThread(String threadId) async {
    final known = await threads();
    if (known.contains(threadId)) return;
    await write(
      'threads',
      jsonEncode({
        'ids': [...known, threadId],
      }),
    );
  }

  static Map? _decode(String? json) {
    if (json == null) return null;
    try {
      return switch (jsonDecode(json)) {
        final Map map => map,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}

/// What a step of a run that is over throws, to stop where it stands.
class _Stopped extends StateError {
  new() : super('device keys are off');
}

/// A pairwise session with one device, and that device's identity key.
typedef _Session = ({String session, String sessionId, String identityKey});
