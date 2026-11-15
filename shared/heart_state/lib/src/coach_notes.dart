import 'dart:async';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'coaching.dart' show CoachingStatus;
import 'device_keys.dart';
import 'remote.dart';

/// What the server does with a coach's notes (heart-of-yours#556): the app's
/// view of a few routes, which the app adapts `Api` onto.
abstract interface class RemoteNoteService {
  Future<CoachNote> saveNote(String id, {required String connectionId, required String content});

  Future<({List<CoachNote> notes, String? cursor})> getNotes({String? connectionId, String? cursor});

  Future<void> deleteNote(String id);
}

/// One stored note: [pending] for a write or a deletion the server hasn't
/// taken, [deleted] for one deleted here.
typedef StoredNote = ({CoachNote note, bool pending, bool deleted});

/// Where a device keeps a coach's notes, so they open offline: ciphertext
/// only, as the server holds it.
abstract interface class LocalNoteService {
  Future<List<StoredNote>> getCoachNotes(String userId);

  /// Adds, or replaces by id.
  Future<void> storeCoachNotes(String userId, Iterable<StoredNote> notes);

  /// Makes [notes] the whole store, except what waits to be sent and the
  /// notes [keep] names, which stay as they are here, or absent.
  Future<void> replaceCoachNotes(String userId, Iterable<CoachNote> notes, {Set<String> keep});

  Future<void> deleteCoachNote(String userId, String id);
}

/// One note as the app shows it.
class ClientNote {
  final String id;

  /// Opened, still waiting for its key, or never to open.
  final OpenedNote opened;

  /// When it was last written: by the server once it has it, by this device
  /// until then.
  final DateTime updatedAt;

  /// Written here, and not yet on the server.
  final bool pending;

  const new({required this.id, required this.opened, required this.updatedAt, required this.pending});

  String? get text => switch (opened) {
    ReadNote(:final text) => text,
    LockedNote() || RefusedNote() => null,
  };
}

/// A coach's notes on their clients (heart-of-yours#556): an injury, what
/// they said about work, what to try next. Only the coach reads them, on any
/// of their devices; the server holds ciphertext, and the client never
/// learns they exist. They stay when a client leaves.
///
/// A note is sealed on this device and kept here first, then sent, so one
/// written at the gym offline waits here, under the id it was written with,
/// and the last write wins on the server.
///
/// Server-backed and opt-in through coaching: nothing is read or sent unless
/// a coach's screen asks, and those exist only with Coach people on.
class CoachNotes with ChangeNotifier implements SignOutStateSentry {
  final RemoteNoteService _service;
  final LocalNoteService _local;
  final NoteCipher _cipher;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final String Function() _newId;
  final DateTime Function() _now;

  new({
    required this._service,
    required this._local,
    required this._cipher,
    RemoteAccess? remote,
    this.onError,
    String Function()? newId,
    DateTime Function()? now,
  }) : _remote = remote ?? RemoteAccess(),
       _newId = newId ?? uuidV7,
       _now = now ?? DateTime.now {
    _keys = _cipher.noteKeys.listen((_) => unawaited(_show()));
  }

  static CoachNotes of(BuildContext context) => Provider.of<CoachNotes>(context, listen: false);

  static CoachNotes watch(BuildContext context) => Provider.of<CoachNotes>(context, listen: true);

  late final StreamSubscription<void> _keys;

  String? _userId;

  String? get userId => _userId;

  set userId(String? value) {
    if (value == _userId) return;
    _forget();
    _userId = value;
  }

  CoachingStatus _status = .idle;

  CoachingStatus get status => _status;

  /// What this device holds, by id: ciphertext, as stored.
  final _stored = <String, StoredNote>{};

  /// What each note opened to, with the content it was opened from.
  final _opened = <String, (String, OpenedNote)>{};

  /// The notes as shown, by the client they are about, last written first.
  var _shown = <String, List<ClientNote>>{};

  /// Changes to [_stored] and the store, one after another. Made by the
  /// first change, in the zone it runs in, not where this was built.
  Future<void>? _turn;

  Future<void>? _flushing;
  var _again = false;

  /// The read on its way, which a second call joins.
  Future<void>? _loading;

  /// The notes written or deleted here since the read on its way began: the
  /// server's copy of them, read meanwhile, is older than this device's.
  Set<String>? _touched;

  /// The notes the server refused for good since the app started: each waits
  /// here, unsent, until it is written again, rather than be sent and
  /// refused on every run.
  final _refused = <String>{};

  /// Whether this read already asked for keys a note waits on.
  var _asked = false;

  /// The notes on [connectionId]'s client, last written first.
  List<ClientNote> on(String connectionId) => _shown[connectionId] ?? const [];

  /// Reads the notes: what this device holds first, then, after sending what
  /// waits here, the server's. A read already on its way is the one asked
  /// for again.
  Future<void> load() {
    if (_loading case final Future<void> running) return running;
    late final Future<void> loading;
    loading = _load().whenComplete(() {
      if (identical(_loading, loading)) _loading = null;
    });
    return _loading = loading;
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) return;
    await _loadHeld(userId);
    if (userId != _userId) return;
    if (!_remote.allowed) {
      // what is held is all there is until the server can be reached
      _status = .loaded;
      notifyListeners();
      return;
    }
    _status = .loading;
    _asked = false;
    final touched = _touched = {};
    notifyListeners();
    try {
      await flush();
      final notes = <CoachNote>[];
      String? cursor;
      do {
        final page = await _service.getNotes(cursor: cursor);
        notes.addAll(page.notes);
        cursor = page.cursor;
      } while (cursor != null);
      await _inTurn(userId, () async {
        await _local.replaceCoachNotes(userId, notes, keep: touched);
        final stored = await _local.getCoachNotes(userId);
        if (userId == _userId) _replace(stored);
      });
      if (userId != _userId) return;
      _status = .loaded;
    } catch (error, stacktrace) {
      if (userId != _userId) return;
      _status = .failed;
      onError?.call(error, stacktrace: stacktrace);
    } finally {
      if (identical(_touched, touched)) _touched = null;
    }
    await _show();
    // another device of the coach's may have come since: it gets the keys
    unawaited(_shareKeys());
  }

  /// Reads again on coming back to the app, once anything was read.
  Future<void> resume() async {
    if (_status != .idle) await load();
  }

  /// What this device holds, when nothing was read yet.
  Future<void> _loadHeld(String userId) async {
    if (_stored.isNotEmpty) return;
    try {
      final held = await _local.getCoachNotes(userId);
      if (userId != _userId || _stored.isNotEmpty) return;
      _replace(held);
      await _show();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  void _replace(List<StoredNote> notes) {
    _stored
      ..clear()
      ..addAll({for (final each in notes) each.note.id: each});
  }

  /// Writes [text] on [connectionId]'s client: as a new note, or in place of
  /// the note [id]. Kept here at once, sealed, and sent when the server can
  /// be reached. Answers the note's id.
  ///
  /// Throws [KeyFailure] `note_too_long` for more than a note holds.
  Future<String> save(String connectionId, String text, {String? id}) async {
    final userId = _userId;
    if (userId == null) throw StateError('no account');
    final noteId = id ?? _newId();
    final content = await _cipher.sealNote(noteId, connectionId: connectionId, text: text);
    if (userId != _userId) return noteId;
    final note = CoachNote(id: noteId, connectionId: connectionId, content: content, updatedAt: _now().toUtc());
    await _inTurn(userId, () async {
      final stored = (note: note, pending: true, deleted: false);
      await _local.storeCoachNotes(userId, [stored]);
      if (userId != _userId) return;
      _stored[noteId] = stored;
      _touched?.add(noteId);
      // written again: worth another try
      _refused.remove(noteId);
      // opened already: these are the words
      _opened[noteId] = (content, ReadNote(text: text, connectionId: connectionId));
    });
    await _show();
    unawaited(flush());
    return noteId;
  }

  /// Deletes the note [id]: gone from here at once, and from the server when
  /// it can be reached.
  Future<void> delete(String id) async {
    final userId = _userId;
    if (userId == null) return;
    await _inTurn(userId, () async {
      final stored = _stored[id];
      if (stored == null) return;
      final deleting = (note: stored.note, pending: true, deleted: true);
      await _local.storeCoachNotes(userId, [deleting]);
      if (userId != _userId) return;
      _stored[id] = deleting;
      _touched?.add(id);
      _refused.remove(id);
    });
    await _show();
    unawaited(flush());
  }

  /// Sends what waits here. One run at a time: a call during a run gets one
  /// more after it.
  Future<void> flush() {
    if (_flushing case final Future<void> running) {
      _again = true;
      return running;
    }
    return _flushing = _flushAll().whenComplete(() => _flushing = null);
  }

  Future<void> _flushAll() async {
    do {
      _again = false;
      await _flushOnce();
    } while (_again);
  }

  Future<void> _flushOnce() async {
    final userId = _userId;
    if (userId == null || !_remote.allowed) return;
    final waiting = _stored.values.where((each) => each.pending && !_refused.contains(each.note.id)).toList();
    if (waiting.isEmpty) return;
    // the coach's other devices read what goes up only with the key
    if (waiting.any((each) => !each.deleted)) await _shareKeys();
    for (final (:note, pending: _, :deleted) in waiting) {
      try {
        switch (deleted) {
          case true:
            await _sendDeletion(userId, note);
          case false:
            await _send(userId, note);
        }
      } on Map catch (refusal) {
        onError?.call(refusal);
        // everything goes again with the next run
        if (refusal['code'] == 'rate_limited') break;
        // refused for this note alone, and for good: the others still go
        _refused.add(note.id);
      } catch (error, stacktrace) {
        // no network, or no answer: everything waits for the next run
        onError?.call(error, stacktrace: stacktrace);
        break;
      }
      if (userId != _userId) return;
    }
    await _show();
  }

  Future<void> _send(String userId, CoachNote note) async {
    final connectionId = note.connectionId;
    // a note is written on a client: one without was never written here
    if (connectionId == null) return;
    final saved = await _service.saveNote(note.id, connectionId: connectionId, content: note.content);
    await _inTurn(userId, () async {
      final current = _stored[note.id];
      // written again, or deleted, while this one travelled: that goes next
      if (current == null || current.deleted || current.note.content != note.content) return;
      final sent = (note: saved, pending: false, deleted: false);
      await _local.storeCoachNotes(userId, [sent]);
      if (userId != _userId) return;
      _stored[note.id] = sent;
      _touched?.add(note.id);
    });
  }

  Future<void> _sendDeletion(String userId, CoachNote note) async {
    try {
      await _service.deleteNote(note.id);
    } on Map catch (refusal) {
      // never reached the server, or deleted from another device: gone either way
      if (refusal['code'] != 'not_found') rethrow;
    }
    await _inTurn(userId, () async {
      if (_stored[note.id] case (pending: _, deleted: true, note: _)) {
        await _local.deleteCoachNote(userId, note.id);
        if (userId != _userId) return;
        _stored.remove(note.id);
        _opened.remove(note.id);
        _touched?.add(note.id);
      }
    });
  }

  Future<void> _shareKeys() async {
    try {
      await _cipher.shareNoteKeys();
    } catch (error, stacktrace) {
      // shared again with the next note or the next read
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Opens what changed since it was last opened, and shows every note but
  /// the deleted, by client.
  Future<void> _show() async {
    final userId = _userId;
    final kept = _stored.values.where((each) => !each.deleted).toList();
    final unopened = [
      for (final each in kept)
        if (_opened[each.note.id]?.$1 != each.note.content) each.note,
    ];
    if (unopened.isNotEmpty) {
      try {
        final opened = await _cipher.openNotes(unopened);
        if (userId != _userId) return;
        // a locked one is tried again each time: its key may come with no
        // word of it, as when keys start after the notes were read
        for (final (index, note) in unopened.indexed.where((each) => opened[each.$1] is! LockedNote)) {
          _opened[note.id] = (note.content, opened[index]);
        }
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
    final shown = <String, List<ClientNote>>{};
    var locked = false;
    for (final (:note, :pending, deleted: _) in _stored.values.where((each) => !each.deleted)) {
      final opened = switch (_opened[note.id]) {
        (final String content, final OpenedNote opened) when content == note.content => opened,
        _ => const LockedNote(),
      };
      locked |= opened is LockedNote;
      // filed by the server, or, where it no longer says, by what was sealed
      final connectionId = switch ((note.connectionId, opened)) {
        (final String id, _) => id,
        (null, ReadNote(:final connectionId)) => connectionId,
        (null, LockedNote() || RefusedNote()) => null,
      };
      if (connectionId == null) continue;
      (shown[connectionId] ??= []).add(
        ClientNote(id: note.id, opened: opened, updatedAt: note.updatedAt, pending: pending),
      );
    }
    for (final notes in shown.values) {
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    _shown = shown;
    notifyListeners();
    // a key may wait on the queue with no push to say so: asked once a read
    if (locked && !_asked && _remote.allowed) {
      _asked = true;
      unawaited(_receive());
    }
  }

  Future<void> _receive() async {
    try {
      await _cipher.receive();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Runs [step] after the changes before it, while [userId] is still the
  /// account: nothing more is changed for one gone meanwhile. A step that
  /// waits on the store checks again after it.
  Future<void> _inTurn(String userId, Future<void> Function() step) {
    final turn = (_turn ?? Future<void>.value()).then((_) async {
      if (userId == _userId) await step();
    });
    _turn = turn.then((_) {}, onError: (_) {});
    return turn;
  }

  void _forget() {
    _stored.clear();
    _opened.clear();
    _refused.clear();
    _loading = null;
    _touched = null;
    _shown = {};
    _status = .idle;
  }

  @override
  void onSignOut() {
    _forget();
    _userId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _keys.cancel();
    _forget();
    super.dispose();
  }
}
