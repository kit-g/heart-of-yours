import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/message_text.dart';
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
  late _Connections connections;
  late Coaching coaching;

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
    connections = _Connections();
    coaching = Coaching(
      service: connections,
      remote: RemoteAccess(hasToken: () => true)..account = true,
    );
    await coaching.load();
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
          ChangeNotifierProvider<Coaching>.value(value: coaching),
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
    final first = tester.getTopLeft(_message('Squats?'));
    final second = tester.getTopLeft(_message('Heavy, but good'));
    expect(first.dy, lessThan(second.dy));
    // under the test font each letter is as wide as it is tall: short words keep the bubbles apart
    expect(second.dx, lessThan(first.dx), reason: "theirs sit left, the coach's own right");
    expect(_message("Waiting for this message's key"), findsOneWidget);
    expect(server.calls, contains('read t1 c3'));
  });

  testWidgets('a long press copies what was said; one that never opened offers nothing', (tester) async {
    server.items = [
      _item('i1', 'Squats?', sender: 'whiskers', cursor: 'c1'),
      _item('i2', 'locked', sender: 'muffin', cursor: 'c2'),
    ];
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

    await tester.longPress(_message("Waiting for this message's key"));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);

    await tester.longPress(_message('Squats?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copied, ['Squats?']);
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('a day of messages opens under its heading', (tester) async {
    final now = DateTime.now();
    server.items = [
      _item('i1', 'Squats?', sender: 'whiskers', cursor: 'c1', at: now.subtract(const Duration(days: 1))),
      _item('i2', 'Heavy', sender: 'muffin', cursor: 'c2', at: now),
    ];

    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('a message written goes out, and the box empties', (tester) async {
    await pump(tester, const ThreadPage(connectionId: 'c-muffin'));
    expect(find.text('No messages yet'), findsOneWidget);

    await tester.enterText(find.byKey(AppKeys.messageBox), 'Deload this week');
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.messageSend));
    await tester.pumpAndSettle();

    expect(server.posted, ['sealed:Deload this week']);
    expect(_message('Deload this week'), findsOneWidget);
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
    expect(_message('Morning!'), findsOneWidget);
    expect(find.text('Pick a conversation'), findsNothing);
  });

  testWidgets('a narrow inbox opens the conversation as a page', (tester) async {
    final opened = <String>[];

    await pump(tester, CoachMessagesPage(onYourTraining: () {}, onOpen: opened.add));
    await tester.tap(find.byKey(AppKeys.inboxThread('t1')));
    await tester.pumpAndSettle();

    expect(opened, ['c-muffin']);
  });

  group('the conversation menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(AppKeys.threadMenu));
      await tester.pumpAndSettle();
    }

    testWidgets('deleting asks first, then empties it for both, and says who did', (tester) async {
      server.items = [_item('i1', 'Squats?', sender: 'whiskers', cursor: 'c1')];
      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.threadDelete));
      await tester.pumpAndSettle();
      expect(find.text('Every message goes, for you and for Muffin. This can\'t be undone.'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.threadDeleteConfirm));
      await tester.pumpAndSettle();

      expect(server.calls, contains('clear t1'));
      expect(_message('Squats?'), findsNothing);
      expect(store.items, isEmpty, reason: 'gone from the device too');
      expect(find.text('You deleted the messages before this.'), findsOneWidget);
    });

    testWidgets('blocking asks first, ends the connection, and closes the box', (tester) async {
      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.threadBlock));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.threadBlockConfirm));
      await tester.pumpAndSettle();

      expect(connections.statuses, [ConnectionStatus.blocked]);
      expect(find.byKey(AppKeys.messageBox), findsNothing);
      expect(find.text('This conversation takes no new messages.'), findsOneWidget);

      await openMenu(tester);
      expect(find.byKey(AppKeys.threadBlock), findsNothing, reason: 'nothing left to block');
    });

    testWidgets('a report sends why, with their messages alone, and blocks when asked', (tester) async {
      server.items = [
        _item('i1', 'Skip the warm-up', sender: 'muffin', cursor: 'c1'),
        _item('i2', 'No', sender: 'whiskers', cursor: 'c2'),
      ];
      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.threadReport));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.reportSend), findsNothing, reason: 'nothing to send before a reason');
      expect(find.text('Include their last messages (1)'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.reportReason('unsafe_advice')));
      await tester.tap(find.byKey(AppKeys.reportBlock));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.reportSend));
      await tester.pumpAndSettle();

      final (:reason, :words) = server.reports.single;
      expect(reason, 'unsafe_advice');
      expect(words, ['Skip the warm-up']);
      expect(connections.statuses, [ConnectionStatus.blocked]);
      expect(find.text('Report sent. You blocked Muffin.'), findsOneWidget);
    });

    testWidgets('a long press reports one message of theirs, and none of the person\'s own', (tester) async {
      server.items = [
        _item('i1', 'Skip the warm-up', sender: 'muffin', cursor: 'c1'),
        _item('i2', 'Mine', sender: 'whiskers', cursor: 'c2'),
      ];
      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

      await tester.longPress(_message('Mine'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.messageReport), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.longPress(_message('Skip the warm-up'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.messageReport));
      await tester.pumpAndSettle();
      expect(find.text('Include this message'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.reportReason('harassment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.reportSend));
      await tester.pumpAndSettle();

      expect(server.reports.single.words, ['Skip the warm-up']);
      expect(connections.statuses, isEmpty);
      expect(find.text('Report sent. Thank you.'), findsOneWidget);
    });

    testWidgets('an ended connection has no box', (tester) async {
      connections.status = .severed;
      await coaching.load();

      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));

      expect(find.byKey(AppKeys.messageBox), findsNothing);
    });

    testWidgets('a sheet closed while the report goes leaves the conversation open', (tester) async {
      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));
      server.holdReport = Completer();
      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.threadReport));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.reportReason('spam')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.reportSend));
      await tester.pump();

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      server.holdReport!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ThreadPage), findsOneWidget);
      expect(find.byKey(AppKeys.reportSheet), findsNothing);
    });

    testWidgets('a report that failed says so on the sheet, which stays', (tester) async {
      await pump(tester, const ThreadPage(connectionId: 'c-muffin'));
      server.reportFails = true;
      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.threadReport));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.reportReason('spam')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.reportSend));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.reportSheet), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(AppKeys.reportSheet), matching: find.text("Couldn't send the report.")),
        findsOneWidget,
      );
    });
  });

  testWidgets('an unread count shows over its icon, said as unread, and nothing at none', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const UnreadBadge(count: 2, child: Icon(Icons.forum_outlined)));

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('Unread: 2'), findsOneWidget);

    await pump(tester, const UnreadBadge(count: 0, child: Icon(Icons.forum_outlined)));
    expect(find.byType(Badge), findsNothing);
    handle.dispose();
  });

  test('unread counts split by whose conversations they are', () async {
    await messages.load();

    expect(messages.unreadIn(coaching.clients.map((each) => each.connectionId)), 2);
    expect(messages.unreadIn(coaching.coaches.map((each) => each.connectionId)), 0);
  });
}

ThreadItem _item(String id, String text, {required String sender, String? cursor, DateTime? at}) {
  at ??= DateTime.utc(2026, 11, 12, 8);
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

/// The coach's one client, Muffin, and what became of the connection.
class _Connections implements CoachingService {
  ConnectionStatus status = .active;
  final statuses = <ConnectionStatus>[];

  Connection _muffin() {
    return Connection(
      targetId: 'muffin',
      role: .coach,
      domain: .fitness,
      status: status,
      createdAt: DateTime.utc(2026, 11, 7),
      connectionId: 'c-muffin',
      acceptedAt: DateTime.utc(2026, 11, 7),
    );
  }

  @override
  Future<List<Connection>> getConnections() async => [_muffin()];

  @override
  Future<List<HiddenWorkout>> getHiddenWorkouts() async => [];

  @override
  Future<Connection> setConnectionStatus(String connectionId, ConnectionStatus status) async {
    statuses.add(status);
    this.status = status;
    return _muffin();
  }

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
  Future<List<Thread>> getThreads() async => [
    switch (clearedAt) {
      final DateTime at => Thread(
        id: _thread.id,
        connectionId: _thread.connectionId,
        otherId: _thread.otherId,
        otherName: _thread.otherName,
        clearedAt: at,
        clearedBy: 'whiskers',
      ),
      null => _thread,
    },
  ];

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

  DateTime? clearedAt;
  final reports = <({String reason, List<String> words})>[];
  Completer<void>? holdReport;
  bool reportFails = false;

  @override
  Future<void> clearThread(String threadId) async {
    calls.add('clear $threadId');
    items = [];
    clearedAt = DateTime.utc(2026, 11, 12, 9);
  }

  @override
  Future<void> fileReport({
    required String reportedId,
    String? connectionId,
    required String reason,
    List<ReportedMessage> messages = const [],
  }) async {
    await holdReport?.future;
    if (reportFails) throw const SocketException('offline');
    reports.add((reason: reason, words: [for (final each in messages) each.words]));
  }
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
  Future<void> deleteThreadItems(String userId, Iterable<String> itemIds) async {
    items.removeWhere((each) => itemIds.contains(each.item.id));
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

/// A message's words, which a [MessageText] lays out with its time.
Finder _message(String text) => find.byWidgetPredicate((widget) => widget is MessageText && widget.text == text);
