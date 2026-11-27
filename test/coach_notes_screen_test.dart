import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'support/harness.dart';

/// A coach's notes on a client, on screen (#556): written, edited and
/// deleted on the device, and what a note that won't open says instead.
void main() {
  late _Server server;
  late _Store store;
  late _Cipher cipher;
  late CoachNotes notes;
  late Roster roster;
  late RecordedAnalytics recorded;

  const client = 'c-muffin';

  setUp(() {
    server = _Server();
    store = _Store();
    cipher = _Cipher();
    recorded = RecordedAnalytics();
    notes = CoachNotes(
      service: server,
      local: store,
      cipher: cipher,
      remote: RemoteAccess(hasToken: () => true)..account = true,
      analytics: Analytics(service: recorded),
    )..userId = 'whiskers';
    roster = Roster(service: _NoRoster());
  });

  tearDown(() => cipher.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachNotes>.value(value: notes),
          ChangeNotifierProvider<Roster>.value(value: roster),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: LayoutProvider(
            currentStack: 0,
            builder: (_, _, _) => const ClientNotesPage(connectionId: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(AppKeys.coachingNoteText), text);
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.coachingNoteSave));
    await tester.pumpAndSettle();
  }

  testWidgets('with none yet, it says what a note is for and who reads it, and offers the first', (tester) async {
    await pump(tester);

    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.byKey(AppKeys.coachingNoteFirst), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.coachingNoteFirst));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.coachingNoteEditor), findsOneWidget);
    expect(find.text('Only you can read these notes. Your client never sees them.'), findsOneWidget);
    expect(find.byKey(AppKeys.coachingNoteSave), findsNothing, reason: 'nothing to save yet');
    expect(find.byKey(AppKeys.coachingNoteDelete), findsNothing, reason: 'a new note has nothing to delete');
  });

  testWidgets('a note written is shown at once, sealed on its way up', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AppKeys.coachingNoteNew));
    await tester.pumpAndSettle();

    await write(tester, 'Left knee: no deep squats');

    expect(find.byKey(AppKeys.coachingNoteEditor), findsNothing);
    expect(find.text('Left knee: no deep squats'), findsOneWidget);
    expect(server.notes.values.single.content, isNot(contains('knee')));
  });

  testWidgets('a note opens to edit, saves over itself, and can be deleted after asking', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AppKeys.coachingNoteNew));
    await tester.pumpAndSettle();
    await write(tester, 'Shoulder');
    final id = server.notes.keys.single;

    await tester.tap(find.text('Shoulder'));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.coachingNoteSave), findsNothing, reason: 'unchanged');
    await write(tester, 'Shoulder, better now');

    expect(find.text('Shoulder, better now'), findsOneWidget);
    expect(server.notes.keys, [id]);

    await tester.tap(find.text('Shoulder, better now'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.coachingNoteDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.coachingNoteDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Shoulder, better now'), findsNothing);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(server.notes, isEmpty);
    // counted as new, then edited, then gone: never the words
    expect(recorded.events.map((each) => each.$1), ['coach_note_saved', 'coach_note_saved', 'coach_note_deleted']);
    expect(recorded.of('coach_note_saved'), [
      {'edited': 'false'},
      {'edited': 'true'},
    ]);
  });

  testWidgets("one whose key hasn't arrived says so, and isn't opened to edit", (tester) async {
    server.notes['n1'] = CoachNote(
      id: 'n1',
      connectionId: client,
      content: 'locked',
      updatedAt: DateTime.utc(2026, 11, 13, 9),
    );
    await pump(tester);

    final locked = find.textContaining('Written on another of your devices');
    expect(locked, findsOneWidget);
    await tester.tap(locked);
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.coachingNoteEditor), findsNothing);
  });

  testWidgets('too long to save is said on the sheet, which stays open', (tester) async {
    cipher.tooLong = true;
    await pump(tester);
    await tester.tap(find.byKey(AppKeys.coachingNoteNew));
    await tester.pumpAndSettle();

    await write(tester, 'a great deal');

    expect(find.byKey(AppKeys.coachingNoteEditor), findsOneWidget);
    expect(find.text('Too long to save. Try splitting it into two notes.'), findsOneWidget);
  });

  testWidgets('a save on its way takes Save away, so a second tap writes no second note', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AppKeys.coachingNoteNew));
    await tester.pumpAndSettle();
    cipher.hold = Completer();

    await tester.enterText(find.byKey(AppKeys.coachingNoteText), 'Hips');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.coachingNoteSave));
    await tester.pump();

    expect(find.byKey(AppKeys.coachingNoteSave), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    cipher.hold!.complete();
    await tester.pumpAndSettle();
    expect(server.notes, hasLength(1));
    expect(find.byKey(AppKeys.coachingNoteEditor), findsNothing);
  });

  testWidgets('a deletion that fails is said on the sheet, which stays open', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(AppKeys.coachingNoteNew));
    await tester.pumpAndSettle();
    await write(tester, 'Shoulder');
    await tester.tap(find.text('Shoulder'));
    await tester.pumpAndSettle();
    store.fails = true;

    await tester.tap(find.byKey(AppKeys.coachingNoteDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.coachingNoteDeleteConfirm));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.coachingNoteEditor), findsOneWidget);
    expect(find.text("Couldn't delete the note. Try again."), findsOneWidget);
  });
}

class _Server implements RemoteNoteService {
  final notes = <String, CoachNote>{};

  @override
  Future<CoachNote> saveNote(String id, {required String connectionId, required String content}) async {
    return notes[id] = CoachNote(
      id: id,
      connectionId: connectionId,
      content: content,
      updatedAt: DateTime.utc(2026, 11, 14, 9, notes.length),
    );
  }

  @override
  Future<({List<CoachNote> notes, String? cursor})> getNotes({String? connectionId, String? cursor}) async {
    return (notes: notes.values.toList(), cursor: null);
  }

  @override
  Future<void> deleteNote(String id) async {
    if (notes.remove(id) == null) {
      throw const ServerRefusal(status: 404, code: 'not_found', method: 'DELETE', route: '/v1/notes/{id}');
    }
  }
}

class _Store implements LocalNoteService {
  final notes = <String, StoredNote>{};

  /// Every write fails, as a full disk would.
  var fails = false;

  @override
  Future<List<StoredNote>> getCoachNotes(String userId) async => [...notes.values];

  @override
  Future<void> storeCoachNotes(String userId, Iterable<StoredNote> stored) async {
    if (fails) throw StateError('disk full');
    for (final each in stored) {
      notes[each.note.id] = each;
    }
  }

  @override
  Future<void> replaceCoachNotes(String userId, Iterable<CoachNote> server, {Set<String> keep = const {}}) async {
    notes.removeWhere((id, each) => !each.pending && !keep.contains(id));
    for (final note in server.where((each) => !keep.contains(each.id))) {
      notes.putIfAbsent(note.id, () => (note: note, pending: false, deleted: false));
    }
  }

  @override
  Future<void> deleteCoachNote(String userId, String id) async => notes.remove(id);
}

/// Seals backwards, so no words show: the real sealing is DeviceKeys'.
class _Cipher implements NoteCipher {
  final _arrivals = StreamController<void>.broadcast();
  var tooLong = false;

  /// Sealing waits here.
  Completer<void>? hold;

  void dispose() => _arrivals.close();

  @override
  Stream<void> get noteKeys => _arrivals.stream;

  @override
  Future<String> sealNote(String noteId, {required String connectionId, required String text}) async {
    await hold?.future;
    if (tooLong) throw const KeyFailure('note_too_long');
    return 'sealed:$connectionId:${text.split('').reversed.join()}';
  }

  @override
  Future<List<OpenedNote>> openNotes(List<CoachNote> notes) async {
    return [
      for (final note in notes)
        switch (note.content.split(':')) {
          ['sealed', final String connectionId, ...final rest] => ReadNote(
            text: rest.join(':').split('').reversed.join(),
            connectionId: connectionId,
          ),
          ['locked'] => const LockedNote(),
          _ => const RefusedNote(),
        },
    ];
  }

  @override
  Future<void> shareNoteKeys() async {}

  @override
  Future<void> receive() async {}
}

class _NoRoster implements RosterService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
