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

  /// Something was kept in the inbox since it was last handed over.
  bool arrived = false;

  /// The last read of the queue brought something.
  bool received = false;

  final peers = <String, Peer>{};

  /// When each thread last shared its keys with every device it knew of.
  final sharedAt = <String, DateTime>{};

  /// Each thread's shares, one after another.
  final sharing = <String, Future<void>>{};

  /// The note keys' turn: their record is read and written one step at a
  /// time, apart from the steps that wait on the network.
  Future<void> notesTail = Future.value();

  /// The server no longer has this device (#750): what it held is forgotten,
  /// and nothing more is read, written or sent until it starts over as a new
  /// one.
  bool removed = false;

  /// Publishes this run saw through: a read of the account's devices that
  /// began before the latest can't tell whether this device is among them.
  int publishes = 0;

  void end() => _over = true;

  /// Throws [_Stopped] once the run is over, and [_Removed] once the device
  /// was removed.
  void check() {
    if (_over) throw _Stopped();
    if (removed) throw _Removed();
  }

  /// What marks this device removed, kept until it starts over.
  static const _removedMark = 'removed';

  /// Whether a removal was marked here, finished or cut short.
  Future<bool> marked() async {
    if (_over) throw _Stopped();
    return await _vault.read(_key(_removedMark)) != null;
  }

  /// Forgets everything the account keeps on this device: its own keys, its
  /// sessions, every thread's and note's keys, what waits in the inbox. The
  /// mark goes first, so a relaunch partway through finds it, forgets the
  /// rest, and seals and answers nothing with what was left.
  Future<void> forgetAll() async {
    if (_over) throw _Stopped();
    final mark = _key(_removedMark);
    await _vault.write(mark, '1');
    for (final name in await _vault.names()) {
      if (name.startsWith(_key('')) && name != mark) await _vault.delete(name);
    }
    removed = true;
    device = null;
    box = null;
    peers.clear();
    sharedAt.clear();
    owing.clear();
    arrived = false;
    received = false;
    status = .removed;
  }

  /// Ends the removal: what starts over is a new device, already kept.
  Future<void> unmark() async {
    if (_over) throw _Stopped();
    await _vault.delete(_key(_removedMark));
  }

  /// One of the account's own devices went: a note key that came from
  /// another device may be held by more than this one knows of, so the next
  /// note seals under one made here.
  Future<void> ownDeviceWent() => write('notes.rekey', '1');

  Future<bool> notesRekey() async => await read('notes.rekey') != null;

  Future<void> notesRekeyed() => forget('notes.rekey');

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

  Future<_Session?> session(String deviceId) => _sessionAt('session.$deviceId');

  Future<void> saveSession(String deviceId, _Session session) => _saveSessionAt('session.$deviceId', session);

  /// The session this device held with [deviceId] when the other side started
  /// one of its own: each may have started one before hearing of the other's,
  /// and the other side may go on with either (#734).
  Future<_Session?> spareSession(String deviceId) => _sessionAt('spare.$deviceId');

  Future<void> saveSpareSession(String deviceId, _Session session) => _saveSessionAt('spare.$deviceId', session);

  Future<void> forgetSessions(String deviceId) async {
    await forget('session.$deviceId');
    await forget('spare.$deviceId');
  }

  Future<_Session?> _sessionAt(String name) async {
    return switch (_decode(await read(name))) {
      {'session': final String session, 'sessionId': final String sessionId, 'identityKey': final String identityKey} =>
        (session: session, sessionId: sessionId, identityKey: identityKey),
      _ => null,
    };
  }

  Future<void> _saveSessionAt(String name, _Session session) {
    return vault.write(
      _key(name),
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

  /// Whether one of [holders], devices each with whose it is, is no longer
  /// among that person's devices as last read: a key one of them holds is
  /// replaced before anything more is sealed under it. Read from the vault,
  /// so a relaunch sees a removal before the next read of the devices does.
  Future<bool> heldByGone(Map<String, String> holders) async {
    for (final owner in holders.values.toSet()) {
      final listed = switch (_decode(await read('seen.$owner'))) {
        final Map seen => seen.keys.toSet(),
        // never read: nothing to tell a removed device from
        null => null,
      };
      if (listed == null) continue;
      final gone = holders.entries.where(
        (each) => each.value == owner && each.key != device?.id && !listed.contains(each.key),
      );
      if (gone.isNotEmpty) return true;
    }
    return false;
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
  new([super.message = 'device keys are off']);
}

/// What a step throws once the server removed this device (#750): stopped
/// the same way, quietly, until it starts over.
class _Removed extends _Stopped {
  new() : super('this device was removed');
}

/// A pairwise session with one device, and that device's identity key.
typedef _Session = ({String session, String sessionId, String identityKey});
