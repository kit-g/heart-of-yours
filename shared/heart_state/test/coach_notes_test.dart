import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// A coach's notes (#556): kept here sealed, sent when the server can be
/// reached, and shown by client.
void main() {
  late _Server server;
  late _Store store;
  late _Cipher cipher;
  late RemoteAccess access;
  late List<Object> errors;
  late CoachNotes notes;
  var ids = 0;
  var minute = 0;

  const me = 'whiskers';
  const client = 'c-muffin';

  CoachNotes build() {
    return CoachNotes(
      service: server,
      local: store,
      cipher: cipher,
      remote: access,
      onError: (error, {stacktrace}) => errors.add(error),
      newId: () => 'n${ids++}',
      now: () => DateTime.utc(2026, 11, 14, 9, minute++),
    )..userId = me;
  }

  setUp(() {
    ids = 0;
    minute = 0;
    server = _Server();
    store = _Store();
    cipher = _Cipher();
    access = RemoteAccess(hasToken: () => true)..account = true;
    errors = [];
    notes = build();
  });

  tearDown(() => cipher.dispose());

  List<String?> texts() => [for (final each in notes.on(client)) each.text];

  test('a note is kept here sealed, shown at once, and sent', () async {
    final id = await notes.save(client, 'left knee');

    expect(texts(), ['left knee']);
    expect(store.notes[me]![id]!.note.content, isNot(contains('knee')));
    await notes.flush();

    expect(server.notes[id]!.content, _Cipher.sealed(id, client, 'left knee'));
    expect(store.notes[me]![id]!.pending, isFalse);
    expect(notes.on(client).single.pending, isFalse);
    expect(cipher.shares, greaterThan(0), reason: "the coach's other devices get the key before the note goes");
  });

  test('written offline, it waits here, and goes on the next read', () async {
    access.account = false;
    final id = await notes.save(client, 'shoulder');
    await notes.flush();
    expect(server.notes, isEmpty);
    expect(notes.on(client).single.pending, isTrue);

    access.account = true;
    await notes.load();

    expect(server.notes.keys, [id]);
    expect(notes.on(client).single.pending, isFalse);
  });

  test('editing writes over the same note, last edit first', () async {
    final first = await notes.save(client, 'one');
    await notes.save(client, 'two');
    await notes.save(client, 'one, edited', id: first);
    await notes.flush();

    expect(texts(), ['one, edited', 'two']);
    expect(server.notes, hasLength(2));
    expect(server.notes[first]!.content, _Cipher.sealed(first, client, 'one, edited'));
  });

  test('an edit made while the last one travelled is not taken for sent', () async {
    final id = await notes.save(client, 'one');
    server.hold = Completer();
    final travelling = notes.flush();
    await pumpEventQueue();
    await notes.save(client, 'two', id: id);
    server.hold!.complete();
    server.hold = null;
    await travelling;
    await notes.flush();

    expect(server.notes[id]!.content, _Cipher.sealed(id, client, 'two'));
    expect(store.notes[me]![id]!.pending, isFalse);
    expect(texts(), ['two']);
  });

  test('a deletion hides it at once, and goes when it can', () async {
    final id = await notes.save(client, 'gone soon');
    await notes.flush();
    access.account = false;

    await notes.delete(id);

    expect(notes.on(client), isEmpty);
    expect(store.notes[me]![id]!.deleted, isTrue);
    expect(server.notes, contains(id));

    access.account = true;
    await notes.flush();
    expect(server.notes, isEmpty);
    expect(store.notes[me], isEmpty);
  });

  test('a note deleted before it ever reached the server is simply gone', () async {
    access.account = false;
    final id = await notes.save(client, 'never sent');
    await notes.delete(id);
    access.account = true;

    await notes.flush();

    expect(store.notes[me], isEmpty);
    expect(errors, isEmpty);
  });

  test("a read takes the server's notes, every page, and keeps what waits here", () async {
    server.notes['s1'] = CoachNote(
      id: 's1',
      connectionId: client,
      content: _Cipher.sealed('s1', client, 'from the tablet'),
      updatedAt: DateTime.utc(2026, 11, 13),
    );
    server.notes['s2'] = CoachNote(
      id: 's2',
      connectionId: 'c-biscuit',
      content: _Cipher.sealed('s2', 'c-biscuit', 'other client'),
      updatedAt: DateTime.utc(2026, 11, 12),
    );
    server.pageSize = 1;
    access.account = false;
    await notes.save(client, 'from the phone');
    access.account = true;

    await notes.load();

    expect(texts(), ['from the phone', 'from the tablet']);
    expect([for (final each in notes.on('c-biscuit')) each.text], ['other client']);
    expect(server.calls.where((each) => each.startsWith('get')), hasLength(3));
    expect(notes.status, CoachingStatus.loaded);
  });

  test("one whose key hasn't arrived is shown locked, asks once, and opens when it comes", () async {
    server.notes['s1'] = CoachNote(
      id: 's1',
      connectionId: client,
      content: 'locked:s1',
      updatedAt: DateTime.utc(2026, 11, 13),
    );

    await notes.load();
    expect(notes.on(client).single.opened, isA<LockedNote>());
    expect(cipher.receives, 1);

    cipher.unlocked = true;
    cipher.arrive();
    await pumpEventQueue();

    expect(texts(), ['the key came']);
  });

  test('one locked before its key came opens on the next showing, with no word of the key', () async {
    server.notes['s1'] = CoachNote(
      id: 's1',
      connectionId: client,
      content: 'locked:s1',
      updatedAt: DateTime.utc(2026, 11, 13),
    );
    await notes.load();
    expect(notes.on(client).single.opened, isA<LockedNote>());

    // as when keys start after the notes were first shown
    cipher.unlocked = true;
    await notes.save(client, 'another');

    expect(texts(), contains('the key came'));
  });

  test('what the device holds shows before the server answers', () async {
    store.notes[me] = {
      'h1': (
        note: CoachNote(
          id: 'h1',
          connectionId: client,
          content: _Cipher.sealed('h1', client, 'held'),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),
        pending: false,
        deleted: false,
      ),
    };
    final seen = <List<String?>>[];
    notes.addListener(() => seen.add(texts()));

    await notes.load();

    expect(seen.first, ['held']);
    expect(texts(), isEmpty, reason: 'the server no longer holds it');
  });

  test('a refusal for one note leaves the others to go', () async {
    // the next id: refused from its first send
    server.refuse['n0'] = {'code': 'not_found'};
    final refused = await notes.save(client, 'refused');
    final fine = await notes.save(client, 'fine');

    await notes.flush();

    expect(server.notes.keys, [fine]);
    expect(store.notes[me]![refused]!.pending, isTrue);
    expect(errors, everyElement(containsPair('code', 'not_found')));
  });

  test('a note refused for good is not sent again, nor reported again, until it is written again', () async {
    server.refuse['n0'] = {'code': 'forbidden'};
    final refused = await notes.save(client, 'refused');
    await notes.flush();

    await notes.load();
    await notes.flush();

    expect(server.calls.where((each) => each == 'save $refused'), hasLength(1));
    expect(errors, hasLength(1));
    expect(notes.on(client).single.pending, isTrue, reason: 'still not synced');

    server.refuse.remove(refused);
    await notes.save(client, 'refused, rewritten', id: refused);
    await notes.flush();
    expect(server.notes.keys, [refused]);
  });

  test('a refusal for being too quick sends everything again with the next run', () async {
    server.refuse['n0'] = {'code': 'rate_limited'};
    final limited = await notes.save(client, 'limited');
    await notes.flush();
    server.refuse.remove(limited);

    await notes.flush();

    expect(server.notes.keys, [limited]);
  });

  test("what is written or deleted here while the server's copy travels is not undone by it", () async {
    await notes.save(client, 'kept');
    final edited = await notes.save(client, 'before');
    final deleted = await notes.save(client, 'deleted');
    await notes.flush();
    server.holdGet = Completer();
    final loading = notes.load();
    await pumpEventQueue();

    await notes.save(client, 'after', id: edited);
    await notes.delete(deleted);
    await notes.save(client, 'new');
    await notes.flush();
    server.holdGet!.complete();
    await loading;

    expect(texts(), unorderedEquals(['kept', 'after', 'new']));
    expect(store.notes[me]!.keys, isNot(contains(deleted)));
    expect(store.notes[me]!.values.where((each) => each.pending), isEmpty);
  });

  test('a read asked for while one is on its way joins it', () async {
    await Future.wait([notes.load(), notes.load()]);

    expect(server.calls.where((each) => each.startsWith('get')), hasLength(1));
  });

  test('a read with the server out of reach shows what is held, not a wait', () async {
    access.account = false;

    await notes.load();

    expect(notes.status, CoachingStatus.loaded);
    expect(server.calls, isEmpty);
  });

  test('a change on its way for one account touches nothing once another signs in', () async {
    store.hold = Completer();
    final first = notes.save(client, 'one');
    await pumpEventQueue();
    final second = notes.save(client, 'two');
    await pumpEventQueue();

    notes.userId = 'biscuit';
    store.hold!.complete();
    await Future.wait([first, second]);
    await pumpEventQueue();

    expect(store.notes[me], hasLength(1), reason: 'the one already on its way to the store');
    expect(notes.on(client), isEmpty);
  });

  test('too long is said at once, and nothing is kept', () async {
    expect(
      notes.save(client, 'x' * 20000),
      throwsA(isA<KeyFailure>().having((each) => each.code, 'code', 'note_too_long')),
    );
    await pumpEventQueue();
    expect(store.notes[me] ?? {}, isEmpty);
  });

  test('a sign-out forgets them here, and the next account sees none', () async {
    await notes.save(client, 'private');

    notes.onSignOut();
    notes.userId = 'biscuit';

    expect(notes.on(client), isEmpty);
  });
}

class _Server implements RemoteNoteService {
  final notes = <String, CoachNote>{};
  final calls = <String>[];
  final refuse = <String, Map<String, String>>{};
  var pageSize = 50;
  Completer<void>? hold;

  /// A read waits here, with the notes as they were when it was asked.
  Completer<void>? holdGet;

  @override
  Future<CoachNote> saveNote(String id, {required String connectionId, required String content}) async {
    calls.add('save $id');
    await hold?.future;
    if (refuse[id] case final Map<String, String> refusal) throw refusal;
    return notes[id] = CoachNote(
      id: id,
      connectionId: connectionId,
      content: content,
      updatedAt: DateTime.utc(2026, 11, 14, 12, notes.length),
    );
  }

  @override
  Future<({List<CoachNote> notes, String? cursor})> getNotes({String? connectionId, String? cursor}) async {
    calls.add('get ${cursor ?? ''}');
    final all = notes.values.toList();
    await holdGet?.future;
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = (start + pageSize).clamp(0, all.length);
    return (notes: all.sublist(start, end), cursor: end < all.length ? '$end' : null);
  }

  @override
  Future<void> deleteNote(String id) async {
    calls.add('delete $id');
    if (notes.remove(id) == null) throw {'code': 'not_found'};
  }
}

class _Store implements LocalNoteService {
  final notes = <String, Map<String, StoredNote>>{};

  /// A write waits here.
  Completer<void>? hold;

  @override
  Future<List<StoredNote>> getCoachNotes(String userId) async => [...?notes[userId]?.values];

  @override
  Future<void> storeCoachNotes(String userId, Iterable<StoredNote> stored) async {
    await hold?.future;
    final mine = notes[userId] ??= {};
    for (final each in stored) {
      mine[each.note.id] = each;
    }
  }

  @override
  Future<void> replaceCoachNotes(String userId, Iterable<CoachNote> server, {Set<String> keep = const {}}) async {
    final mine = notes[userId] ??= {};
    mine.removeWhere((id, each) => !each.pending && !keep.contains(id));
    for (final note in server.where((each) => !keep.contains(each.id))) {
      mine.putIfAbsent(note.id, () => (note: note, pending: false, deleted: false));
    }
  }

  @override
  Future<void> deleteCoachNote(String userId, String id) async => notes[userId]?.remove(id);
}

/// Seals in the clear, marked, so a test can read what went where: the real
/// sealing is DeviceKeys', tested with the library itself.
class _Cipher implements NoteCipher {
  final _arrivals = StreamController<void>.broadcast();
  var shares = 0;
  var receives = 0;
  var unlocked = false;

  void arrive() => _arrivals.add(null);

  /// What sealing [text] gives: backwards, so no words show.
  static String sealed(String noteId, String connectionId, String text) {
    return 'sealed:$noteId:$connectionId:${text.split('').reversed.join()}';
  }

  void dispose() => _arrivals.close();

  @override
  Stream<void> get noteKeys => _arrivals.stream;

  @override
  Future<String> sealNote(String noteId, {required String connectionId, required String text}) async {
    if (text.length > 16000) throw const KeyFailure('note_too_long');
    return sealed(noteId, connectionId, text);
  }

  @override
  Future<List<OpenedNote>> openNotes(List<CoachNote> notes) async {
    return [
      for (final note in notes)
        switch (note.content.split(':')) {
          ['sealed', _, final String connectionId, ...final rest] => ReadNote(
            text: rest.join(':').split('').reversed.join(),
            connectionId: connectionId,
          ),
          ['locked', _] when unlocked => ReadNote(text: 'the key came', connectionId: note.connectionId!),
          ['locked', _] => const LockedNote(),
          _ => const RefusedNote(),
        },
    ];
  }

  @override
  Future<void> shareNoteKeys() async => shares++;

  @override
  Future<void> receive() async => receives++;
}
