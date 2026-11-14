part of '../device_keys.dart';

/// What became of opening one of a coach's notes.
sealed class OpenedNote {
  const new();
}

/// Opened: the words, and the client they are about, as sealed with them.
final class ReadNote extends OpenedNote {
  final String text;
  final String connectionId;

  const new({required this.text, required this.connectionId});
}

/// Sealed under a key that hasn't reached this device yet: it opens once it
/// arrives.
final class LockedNote extends OpenedNote {
  const new();
}

/// Never opens here: not a sealed note, sealed for another note or another
/// client, or under a key that doesn't open it.
final class RefusedNote extends OpenedNote {
  const new();
}

/// What a coach's notes want of encryption (#556): sealing for the coach
/// alone, keys on every device of theirs, and opening what is stored.
abstract interface class NoteCipher {
  /// Seals [text], on the client of [connectionId], as the note [noteId].
  /// Needs no network. Throws [KeyFailure] `note_too_long` past what the
  /// server stores.
  Future<String> sealNote(String noteId, {required String connectionId, required String text});

  /// Opens each of [notes]. One whose sealed client isn't the one the server
  /// files it under is [RefusedNote].
  Future<List<OpenedNote>> openNotes(List<CoachNote> notes);

  /// Hands the account's note keys to each of its devices that doesn't hold
  /// them yet.
  Future<void> shareNoteKeys();

  /// Reads what waits for this device, note keys among it.
  Future<void> receive();

  /// A note key just arrived, so what was [LockedNote] can open.
  Stream<void> get noteKeys;
}

/// A coach's notes (#556): sealed for the coach alone, under a key only the
/// coach's devices hold, so the server stores what it can't read and the
/// client never learns of.
///
/// One key serves every note. A device that has none makes one; the first
/// device to write a note does. Each device hands every key it holds to the
/// account's other devices, inside pairwise sessions, and seals under the
/// newest key it holds, so two devices that each made one before hearing of
/// the other end up sealing under the same one.
///
/// A note is bound to the account, its own id and the key it was sealed
/// under, so the server can't pass one note off as another; the client it is
/// about is sealed inside it, so the server can't file it under someone else.
extension _Notes on DeviceKeys {
  static const _context = 'heart-of.me/coach-note/v1';

  /// The most the server stores of one note.
  static const _most = 16 * 1024;

  /// What [_Run.sharedAt] keeps the note keys' last share under: never a
  /// thread's id, which are UUIDs.
  static const _sharedAt = 'notes';

  /// How long a share that reached every device holds before the devices are
  /// read again, unless one of them changed meanwhile.
  static const _shareLife = Duration(minutes: 10);

  static String _contextOf(String userId, String noteId, String keyId) => [_context, userId, noteId, keyId].join('\n');

  Future<String> _sealNote(String noteId, String connectionId, String text) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    return _serial(run, () async {
      final record = await _NoteKeys.read(run);
      final (keyId, key) = record.current ?? await _newNoteKey(run, record);
      final sealed = _guard(
        () => Sealbox.sealNote(
          key: key,
          context: _contextOf(run.userId, noteId, keyId),
          plaintext: jsonEncode({'c': connectionId, 't': text}),
        ),
      );
      final content = _NoteEnvelope(keyId: keyId, sealed: sealed).encode();
      if (content.length > _most) throw const KeyFailure('note_too_long');
      return content;
    });
  }

  Future<(String, String)> _newNoteKey(_Run run, _NoteKeys record) async {
    final made = (_newId(), _guard(Sealbox.newNoteKey));
    record.keys[made.$1] = made.$2;
    await record.save(run);
    return made;
  }

  Future<List<OpenedNote>> _openNotes(List<CoachNote> notes) async {
    final run = _run;
    if (run == null) return [for (final _ in notes) const LockedNote()];
    final record = await _serial(run, () => _NoteKeys.read(run));
    return [for (final note in notes) _openNote(run, record, note)];
  }

  OpenedNote _openNote(_Run run, _NoteKeys record, CoachNote note) {
    final envelope = _NoteEnvelope.decode(note.content);
    if (envelope == null) return const RefusedNote();
    final key = record.keys[envelope.keyId];
    if (key == null) return const LockedNote();
    try {
      final opened = Sealbox.openNote(
        key: key,
        context: _contextOf(run.userId, note.id, envelope.keyId),
        sealed: envelope.sealed,
      );
      return switch (_decodeMap(opened)) {
        // filed under another client than it was written about
        {'c': final String connectionId} when note.connectionId != null && note.connectionId != connectionId =>
          const RefusedNote(),
        {'c': final String connectionId, 't': final String text} => ReadNote(text: text, connectionId: connectionId),
        _ => const RefusedNote(),
      };
    } on SealboxException {
      return const RefusedNote();
    }
  }

  Future<void> _shareNoteKeys() async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    var record = await _serial(run, () => _NoteKeys.read(run));
    if (record.keys.isEmpty) return;
    final fresh = switch (run.sharedAt[_sharedAt]) {
      final DateTime at => _now().difference(at) < _shareLife,
      null => false,
    };
    final own = run.peers[run.userId];
    bool covered(String keyId) {
      return own != null &&
          own.devices.every((each) => each.id == run.device?.id || (record.shared[keyId]?.contains(each.id) ?? false));
    }

    if (fresh && record.keys.keys.every(covered)) return;

    final listed = {for (final each in (await devicesOf(run.userId)).devices) each.id};
    for (final MapEntry(key: keyId, value: key) in record.keys.entries) {
      final missing = listed.where((id) => id != run.device?.id && !(record.shared[keyId]?.contains(id) ?? false));
      if (missing.isEmpty) continue;
      final targets = missing.toSet();
      final reached = await deliver(
        userId: run.userId,
        kind: DeviceKeys.noteKeyKind,
        payload: jsonEncode({'i': keyId, 'k': key}),
        to: (device) => targets.contains(device.id),
      );
      if (reached.isEmpty) continue;
      record = await _serial(run, () async {
        final latest = await _NoteKeys.read(run);
        (latest.shared[keyId] ??= {}).addAll(reached);
        await latest.save(run);
        return latest;
      });
    }
    run.sharedAt[_sharedAt] = _now();
  }

  /// Takes a note key another device of the account's shared.
  Future<void> _takeNoteKey(KeyDelivery delivery) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    // a note key comes from the account's own devices, or from nowhere
    if (delivery.fromUserId != run.userId) {
      _report(const KeyFailure('foreign_note_key'));
      return;
    }
    final (keyId, key) = switch (_decodeMap(delivery.payload)) {
      {'i': final String keyId, 'k': final String key} when keyId.isNotEmpty && _isNoteKey(key) => (keyId, key),
      // nothing will ever open with it: taken, and dropped
      _ => (null, null),
    };
    if (keyId == null || key == null) {
      _report(const KeyFailure('unreadable_note_key'));
      return;
    }
    final taken = await _serial(run, () async {
      final record = await _NoteKeys.read(run);
      // the first one kept: a key id names one key
      if (record.keys.containsKey(keyId)) return false;
      record.keys[keyId] = key;
      // the device it came from holds it
      (record.shared[keyId] ??= {}).add(delivery.fromDeviceId);
      await record.save(run);
      return true;
    });
    if (taken && !_noteKeys.isClosed) _noteKeys.add(null);
  }

  /// Whether the library takes [key] as a note key.
  static bool _isNoteKey(String key) {
    try {
      Sealbox.sealNote(key: key, context: _context, plaintext: '');
      return true;
    } on SealboxException {
      return false;
    }
  }
}

/// What travels as a note's content: the key it was sealed under, which the
/// sealed bytes don't name, and those bytes. `n1.<key id>.<sealed>`.
class _NoteEnvelope {
  final String keyId;
  final String sealed;

  const new({required this.keyId, required this.sealed});

  static const _version = 'n1';

  String encode() => [_version, keyId, sealed].join('.');

  static _NoteEnvelope? decode(String content) {
    return switch (content.split('.')) {
      [_version, final String keyId, final String sealed] when keyId.isNotEmpty && sealed.isNotEmpty => _NoteEnvelope(
        keyId: keyId,
        sealed: sealed,
      ),
      _ => null,
    };
  }
}

/// The account's note keys, by id, and the devices each reached.
class _NoteKeys {
  final Map<String, String> keys;
  final Map<String, Set<String>> shared;

  const new(this.keys, this.shared);

  /// None yet: filled as keys are made or arrive.
  new empty() : keys = {}, shared = {};

  /// The newest: what a note is sealed under.
  (String, String)? get current {
    if (keys.isEmpty) return null;
    final id = (keys.keys.toList()..sort()).last;
    return (id, keys[id]!);
  }

  static Future<_NoteKeys> read(_Run run) async {
    return switch (_Run._decode(await run.read('notes'))) {
      {'keys': final Map keys, 'shared': final Map shared} => _NoteKeys(
        {
          for (final MapEntry(:key, :value) in keys.entries)
            if (value case final String each) '$key': each,
        },
        {
          for (final MapEntry(:key, :value) in shared.entries)
            if (value case final List devices) '$key': {for (final each in devices) '$each'},
        },
      ),
      _ => _NoteKeys.empty(),
    };
  }

  Future<void> save(_Run run) {
    return run.write(
      'notes',
      jsonEncode({
        'keys': keys,
        'shared': {for (final MapEntry(:key, :value) in shared.entries) key: value.toList()},
      }),
    );
  }
}
