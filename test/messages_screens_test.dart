import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/routes/messages/messages.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Coaching messages on screen (#556): a conversation in the server's order,
/// writing in it, and a coach's inbox beside the open one on a wide pane.
void main() {
  late _Server server;
  late _Store store;
  late _Cipher cipher;
  late Messages messages;
  late Preferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    server = _Server();
    store = _Store();
    cipher = _Cipher();
    messages = Messages(
      service: server,
      local: store,
      cipher: cipher,
      remote: RemoteAccess(hasToken: () => true)..account = true,
    )..userId = 'whiskers';
  });

  Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Messages>.value(value: messages),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Coaching>(create: (_) => Coaching(service: _NoCoaching())),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: LayoutProvider(currentStack: 0, builder: (_, _, _) => child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("a conversation reads oldest to newest, and says what couldn't be opened", (tester) async {
    server.items = [
      _item('i1', 'Squats?', sender: 'whiskers', cursor: 'c1'),
      _item('i2', 'Heavy, but good', sender: 'muffin', cursor: 'c2'),
      _item('i3', 'locked', sender: 'muffin', cursor: 'c3'),
    ];

    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

    expect(find.text('Muffin'), findsOneWidget, reason: "the page is titled with who it's with");
    final first = tester.getTopLeft(find.text('Squats?'));
    final second = tester.getTopLeft(find.text('Heavy, but good'));
    expect(first.dy, lessThan(second.dy));
    // under the test font each letter is as wide as it is tall: short words keep the bubbles apart
    expect(second.dx, lessThan(first.dx), reason: "theirs sit left, the coach's own right");
    expect(find.text("Waiting for this message's key"), findsOneWidget);
    expect(server.calls, contains('read t1 c3'));
  });

  testWidgets('a message written goes out, and the box empties', (tester) async {
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));
    expect(find.text('No messages yet'), findsOneWidget);

    await tester.enterText(find.byKey(AppKeys.messageBox), 'Deload this week');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.messageSend));
    await tester.pumpAndSettle();

    expect(server.posted, ['sealed:Deload this week']);
    expect(find.text('Deload this week'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(AppKeys.messageBox)).controller!.text, isEmpty);
  });

  testWidgets("one that can't be sealed stays in the box, and says so", (tester) async {
    cipher.sealFails = true;
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

    await tester.enterText(find.byKey(AppKeys.messageBox), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.messageSend));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(AppKeys.messageBox)).controller!.text, 'Hello');
    expect(find.text("Couldn't send that. Your words are still here."), findsOneWidget);
  });

  testWidgets('what was being written survives the screen closing', (tester) async {
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));
    await tester.enterText(find.byKey(AppKeys.messageBox), 'half a tho');
    await tester.pump();

    await pump(tester, const SizedBox());
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

    expect(tester.widget<TextField>(find.byKey(AppKeys.messageBox)).controller!.text, 'half a tho');
  });

  testWidgets('a closed conversation has no box, and says why', (tester) async {
    server.closed = true;
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));
    await tester.enterText(find.byKey(AppKeys.messageBox), 'Still there?');
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.messageSend));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.messageBox), findsNothing);
    expect(find.text('This conversation takes no new messages.'), findsOneWidget);
    expect(find.text('Not sent'), findsOneWidget);
  });

  testWidgets('a wide inbox opens the conversation beside the list', (tester) async {
    server.items = [_item('i1', 'Morning!', sender: 'muffin', cursor: 'c1')];
    final opened = <String>[];

    await pump(
      tester,
      CoachMessagesPage(onYourTraining: () {}, onOpen: opened.add),
      size: const Size(1000, 800),
    );
    expect(find.text('Pick a conversation'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'the unread count');

    await tester.tap(find.byKey(AppKeys.inboxThread('t1')));
    await tester.pumpAndSettle();

    expect(opened, isEmpty, reason: 'no page of its own');
    expect(find.text('Morning!'), findsOneWidget);
    expect(find.text('Pick a conversation'), findsNothing);
  });

  testWidgets('a narrow inbox opens the conversation as a page', (tester) async {
    final opened = <String>[];

    await pump(tester, CoachMessagesPage(onYourTraining: () {}, onOpen: opened.add));
    await tester.tap(find.byKey(AppKeys.inboxThread('t1')));
    await tester.pumpAndSettle();

    expect(opened, ['c-muffin']);
  });
}

ThreadItem _item(String id, String text, {required String sender, String? cursor}) {
  final at = DateTime.utc(2026, 11, 12, 8);
  return ThreadItem(
    id: id,
    threadId: 't1',
    senderId: sender,
    kind: 'message',
    content: 'sealed:$text',
    commitment: 'c',
    tag: 't',
    tagKey: 'k',
    at: at,
    createdAt: at,
    cursor: cursor,
  );
}

class _NoCoaching implements CoachingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Server implements RemoteThreadService {
  final calls = <String>[];
  List<ThreadItem> items = [];
  final posted = <String>[];
  bool closed = false;

  final _thread = Thread(
    id: 't1',
    connectionId: 'c-muffin',
    otherId: 'muffin',
    otherName: 'Muffin',
    unread: 2,
    lastAt: DateTime.utc(2026, 11, 12, 8),
  );

  @override
  Future<Thread> openThread(String connectionId) async => _thread;

  @override
  Future<List<Thread>> getThreads() async => [_thread];

  @override
  Future<ThreadItem> postThreadItem(
    String threadId, {
    required String id,
    required String content,
    required String commitment,
    required DateTime at,
    String? subjectType,
    String? subjectId,
  }) async {
    posted.add(content);
    if (closed) throw {'error': 'forbidden', 'code': 'thread_closed'};
    return ThreadItem(
      id: id,
      threadId: threadId,
      senderId: 'whiskers',
      kind: 'message',
      content: content,
      commitment: commitment,
      tag: 't',
      tagKey: 'k',
      at: at,
      createdAt: at,
    );
  }

  @override
  Future<({List<ThreadItem> items, String? cursor})> getThreadItems(
    String threadId, {
    String? since,
    String? before,
    int? limit,
  }) async {
    if (since != null) return (items: <ThreadItem>[], cursor: null);
    return (items: items.reversed.toList(), cursor: null);
  }

  @override
  Future<void> markThreadRead(String threadId, String cursor) async => calls.add('read $threadId $cursor');
}

class _Store implements LocalThreadService {
  final threads = <Thread>[];
  final items = <StoredItem>[];

  @override
  Future<List<Thread>> getThreads(String userId) async => [...threads];

  @override
  Future<void> storeThreads(String userId, Iterable<Thread> threads) async {
    this.threads
      ..clear()
      ..addAll(threads);
  }

  @override
  Future<void> storeThread(String userId, Thread thread) async {
    threads
      ..removeWhere((each) => each.id == thread.id)
      ..add(thread);
  }

  @override
  Future<List<StoredItem>> getThreadItems(String userId, String threadId) async {
    final placed = items.where((each) => each.position != null).toList()
      ..sort((a, b) => a.position!.compareTo(b.position!));
    return [...placed, ...items.where((each) => each.position == null)];
  }

  @override
  Future<void> storeThreadItems(String userId, Iterable<StoredItem> stored) async {
    for (final each in stored) {
      items
        ..removeWhere((old) => old.item.id == each.item.id)
        ..add(each);
    }
  }
}

class _Cipher implements ThreadCipher {
  @override
  Future<void> receive() async {}

  bool sealFails = false;

  @override
  Stream<String> get threadKeys => const Stream.empty();

  @override
  Future<SealedMessage> seal(String threadId, String text) async {
    if (sealFails) throw StateError('device keys are off');
    return (content: 'sealed:$text', commitment: 'c');
  }

  @override
  Future<void> share(String threadId, {required String userId, String? fingerprint}) async {}

  @override
  Future<List<OpenedMessage>> open(String threadId, List<ThreadCiphertext> items) async {
    return [
      for (final each in items)
        switch (each.content) {
          'sealed:locked' => const Locked(),
          final String content => Opened(text: content.substring('sealed:'.length), frankingKey: 'f'),
        },
    ];
  }
}
