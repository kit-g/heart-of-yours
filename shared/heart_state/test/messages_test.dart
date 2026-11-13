import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Coaching messages (#556): the inbox, a thread in the server's order, and
/// sending that waits on the device until it can go.
void main() {
  late _Server server;
  late _Store store;
  late _Cipher cipher;
  late RemoteAccess access;
  late List<Object> errors;
  late Messages messages;
  var ids = 0;

  const me = 'muffin';
  const coach = 'whiskers';
  const threadId = 't1';

  Messages build() {
    return Messages(
      service: server,
      local: store,
      cipher: cipher,
      remote: access,
      onError: (error, {stacktrace}) => errors.add(error),
      fingerprintFor: (thread) => 'print-${thread.connectionId}',
      newId: () => 'mine-${ids++}',
      now: () => DateTime.utc(2026, 11, 12, 9),
    )..userId = me;
  }

  setUp(() {
    ids = 0;
    server = _Server();
    store = _Store();
    cipher = _Cipher();
    access = RemoteAccess(hasToken: () => true)..account = true;
    errors = [];
    server.threads = [
      Thread(
        id: threadId,
        connectionId: 'c1',
        otherId: coach,
        otherName: 'Whiskers',
        unread: 2,
        lastAt: DateTime.utc(2026, 11, 12),
      ),
    ];
    messages = build();
  });

  tearDown(() => cipher.dispose());

  group('the inbox', () {
    test('what the device holds first, then the server\'s, kept for next time', () async {
      store.threads[me] = [Thread(id: 'old', otherName: 'Biscuit')];
      final seen = <List<String>>[];
      messages.addListener(() => seen.add(messages.threads.map((each) => each.id).toList()));

      await messages.load();

      expect(seen.first, ['old']);
      expect(messages.threads.single.id, threadId);
      expect(messages.unread, 2);
      expect(store.threads[me]!.single.id, threadId);
      expect(messages.status, CoachingStatus.loaded);
    });

    test('a connection\'s thread is opened on the server once', () async {
      server.threads = [];

      final first = await messages.threadFor('c9');
      final second = await messages.threadFor('c9');

      expect(identical(first, second), isTrue);
      expect(server.calls.where((each) => each.startsWith('open')), ['open c9']);
    });

    test('nothing goes over the wire with the remote leg closed', () async {
      access.account = false;

      await messages.load();
      await messages.open(threadId);

      expect(server.calls, isEmpty);
    });
  });

  group('a thread', () {
    test("opens in the server's order, marks read to the newest, and says whose is whose", () async {
      server.items = [
        _item('a', sender: coach, cursor: 'c1'),
        _item('b', sender: me, cursor: 'c2'),
        _item('c', sender: coach, cursor: 'c3'),
      ];
      await messages.load();

      await messages.open(threadId);

      final thread = messages.thread(threadId);
      expect(thread.messages.map((each) => each.text), ['a', 'b', 'c']);
      expect(thread.messages.map((each) => each.mine), [false, true, false]);
      expect(server.calls.last, 'read t1 c3');
      expect(messages.unread, 0);
    });

    test('what arrived later reads from the newest held, page after page', () async {
      server.items = [_item('a', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      server.items = [_item('a', cursor: 'c1'), _item('b', cursor: 'c2'), _item('c', cursor: 'c3')];
      server.pageSize = 1;

      await messages.arrived(threadId);

      expect(messages.thread(threadId).messages.map((each) => each.text), ['a', 'b', 'c']);
      expect(server.calls.where((each) => each.startsWith('items')), [
        'items t1 newest',
        'items t1 since c1',
        'items t1 since c2',
      ]);
    });

    test('older pages go before what the device holds', () async {
      server.items = [
        for (final each in ['a', 'b', 'c']) _item(each, cursor: 'c-$each'),
      ];
      server.pageSize = 1;
      await messages.load();
      await messages.open(threadId);
      expect(messages.thread(threadId).hasOlder, isTrue);

      await messages.older(threadId);

      expect(messages.thread(threadId).messages.map((each) => each.text), ['b', 'c']);
    });

    test('one sealed under a key not here yet opens when the key arrives', () async {
      server.items = [_item('later', cursor: 'c1')];
      cipher.missing.add('later');
      await messages.load();
      await messages.open(threadId);
      expect(messages.thread(threadId).messages.single.opened, isA<Locked>());

      cipher.missing.clear();
      cipher.arrive(threadId);
      await pumpEventQueue();

      expect(messages.thread(threadId).messages.single.text, 'later');
    });

    test('one shown locked reads the key queue, since no push may have said a key waits there', () async {
      server.items = [_item('queued', cursor: 'c1')];
      cipher.missing.add('queued');
      cipher.queued = {threadId};
      await messages.load();

      await messages.open(threadId);
      await pumpEventQueue();

      expect(cipher.receives, 1);
      expect(messages.thread(threadId).messages.single.text, 'queued');
    });

    test('coming back to the front reads the inbox and the thread on screen', () async {
      server.items = [_item('first', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      server.items = [...server.items, _item('second', cursor: 'c2')];

      await messages.resume();

      expect(messages.thread(threadId).messages.map((each) => each.text), ['first', 'second']);
    });

    test('coming back before anything read the inbox reads nothing', () async {
      await messages.resume();

      expect(messages.status, CoachingStatus.idle);
    });

    test('nothing locked reads no queue', () async {
      server.items = [_item('open', cursor: 'c1')];
      await messages.load();

      await messages.open(threadId);

      expect(cipher.receives, 0);
    });

    test('what came before the other person deleted the conversation is gone', () async {
      server.items = [_item('before', cursor: 'c1', createdAt: DateTime.utc(2026, 11, 10))];
      await messages.load();
      await messages.open(threadId);
      server.threads = [Thread(id: threadId, otherId: coach, clearedAt: DateTime.utc(2026, 11, 11), clearedBy: coach)];
      server.items = [_item('after', cursor: 'c2', createdAt: DateTime.utc(2026, 11, 12))];

      await messages.cleared(threadId);

      expect(messages.thread(threadId).messages.map((each) => each.text), ['after']);
      expect(store.items[me]!.map((each) => each.item.id), ['item-after'], reason: 'gone from the device too');
    });

    test('deleting it here asks the server, and forgets it on the device, what waits to be sent aside', () async {
      server.items = [_item('a', cursor: 'c1', createdAt: DateTime.utc(2026, 11, 10))];
      await messages.load();
      await messages.open(threadId);
      access.account = false;
      await messages.send(threadId, 'unsent');
      access.account = true;
      server.clearedAt = DateTime.utc(2026, 11, 11);

      await messages.clear(threadId);

      expect(server.calls, contains('clear t1'));
      expect(messages.thread(threadId).messages.map((each) => each.text), ['unsent']);
      expect(store.items[me]!.map((each) => each.item.id), ['mine-0']);
    });

    test('a report carries the reason, and the opened words of the other person alone, with their proof', () async {
      server.items = [
        _item('rude', cursor: 'c1'),
        _item('mine', sender: me, cursor: 'c2'),
      ];
      await messages.load();
      await messages.open(threadId);

      await messages.report(
        messages.lookup(threadId)!,
        ReportReason.unsafeAdvice,
        messages: messages.thread(threadId).messages,
      );

      final (:reportedId, :reason, :reported) = server.reports.single;
      expect((reportedId, reason), (coach, 'unsafe_advice'));
      expect(reported.single, (
        words: 'rude',
        key: 'f',
        commitment: 'c',
        tag: 'tag',
        tagKey: 'k',
        senderId: coach,
        recipientId: me,
        createdAt: DateTime.utc(2026, 11, 12, 8),
      ));
    });
  });

  group('screens', () {
    test('what arrives while a read is under way is read after it', () async {
      server.items = [_item('a', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      server.holdPage = Completer();

      final reading = messages.pull(threadId);
      await pumpEventQueue();
      server.items = [_item('a', cursor: 'c1'), _item('b', cursor: 'c2')];
      final pushed = messages.arrived(threadId);
      await pumpEventQueue();
      server.holdPage!.complete();
      await Future.wait([reading, pushed]);

      expect(messages.thread(threadId).messages.map((each) => each.text), ['a', 'b']);
    });

    test('a thread two screens show stays when one closes, and one nobody shows is not read on a push', () async {
      server.items = [_item('a', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      await messages.open(threadId);

      messages.close(threadId);
      expect(messages.thread(threadId).messages, hasLength(1));

      messages.close(threadId);
      server.items = [_item('a', cursor: 'c1'), _item('b', cursor: 'c2')];
      server.calls.clear();
      await messages.arrived(threadId);

      expect(server.calls, ['threads'], reason: 'the inbox, and nothing of the thread');
    });

    test('opened again, older messages are still offered, and a short thread offers none', () async {
      server.items = [
        for (final each in ['a', 'b', 'c']) _item(each, cursor: 'c-$each'),
      ];
      server.pageSize = 1;
      await messages.load();
      await messages.open(threadId);
      messages.close(threadId);

      final again = build();
      await again.load();
      await again.open(threadId);
      expect(again.thread(threadId).hasOlder, isTrue);

      server.items = [_item('a', cursor: 'c-a')];
      final short = build();
      store.items.clear();
      await short.load();
      await short.open(threadId);
      short.close(threadId);
      final shortAgain = build();
      await shortAgain.load();
      await shortAgain.open(threadId);
      expect(shortAgain.thread(threadId).hasOlder, isFalse);
    });

    test('offline, a conversation the device holds opens from it', () async {
      await messages.load();
      access.account = false;
      server.calls.clear();

      final thread = await build().threadFor('c1');

      expect(thread.id, threadId);
      expect(server.calls, isEmpty);
    });

    test('coming back to the front reads the thread on screen even before the inbox was read', () async {
      server.items = [_item('a', cursor: 'c1')];
      // a student's way in: the conversation of their coach, never the inbox
      store.threads[me] = server.threads;
      final thread = await messages.threadFor('c1');
      expect(messages.status, CoachingStatus.idle);
      await messages.open(thread.id);
      server.items = [_item('a', cursor: 'c1'), _item('b', cursor: 'c2')];

      await messages.resume();

      expect(messages.thread(thread.id).messages.map((each) => each.text), ['a', 'b']);
    });
  });

  group('sending', () {
    test('shares the key first, then sends, under the id it was written with', () async {
      await messages.load();

      await messages.send(threadId, 'my knee', subjectType: 'workout', subjectId: 'w1');

      expect(cipher.shares, ['t1 $coach print-c1']);
      expect(server.posted.single, (id: 'mine-0', content: 'sealed:my knee', subjectId: 'w1'));
      final sent = messages.thread(threadId).messages.single;
      expect((sent.text, sent.mine, sent.delivery), ('my knee', true, MessageDelivery.sent));
    });

    test('what went out reads the inbox again, so the thread moves up it', () async {
      await messages.load();
      server.calls.clear();

      await messages.send(threadId, 'top of the list');

      expect(server.calls.where((each) => each == 'threads'), hasLength(1));
    });

    test('written offline, it waits on the device, sealed, and goes later as the same message', () async {
      await messages.load();
      access.account = false;

      await messages.send(threadId, 'later');

      expect(messages.thread(threadId).messages.single.delivery, MessageDelivery.waiting);
      expect(store.items[me]!.single.item.content, 'sealed:later', reason: 'kept sealed, never in the clear');
      expect(server.posted, isEmpty);

      access.account = true;
      server.failNextPost = const _Unreachable();
      await messages.flush(threadId);
      await messages.flush(threadId);

      expect(server.posted.map((each) => each.id), ['mine-0', 'mine-0']);
      expect(messages.thread(threadId).messages.single.delivery, MessageDelivery.sent);
    });

    test('a key that could not be shared holds the message back', () async {
      await messages.load();
      cipher.shareFails = const KeyMismatch(coach);

      await messages.send(threadId, 'hello');

      expect(server.posted, isEmpty);
      expect(messages.thread(threadId).messages.single.delivery, MessageDelivery.waiting);
      expect(errors.single, isA<KeyMismatch>());
    });

    test('a closed thread keeps the message here, unsent, and says so', () async {
      await messages.load();
      server.refusePost = {'error': 'forbidden', 'code': 'thread_closed', 'reason': '…'};

      await messages.send(threadId, 'still there?');

      final thread = messages.thread(threadId);
      expect(thread.closed, isTrue);
      expect(thread.messages.single.delivery, MessageDelivery.closed);
      expect(errors, isEmpty);
    });

    testWidgets('too many at once waits as long as the server says, then goes', (tester) async {
      // the test's fake clock: the wait passes without real seconds
      await messages.load();
      server.refusePost = {'error': 'too many requests', 'code': 'rate_limited', 'retryAfter': 30};

      await messages.send(threadId, 'one more');
      expect(messages.thread(threadId).messages.single.delivery, MessageDelivery.waiting);

      server.refusePost = null;
      await tester.pump(const Duration(seconds: 29));
      expect(server.posted, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(server.posted, hasLength(2));
      expect(messages.thread(threadId).messages.single.delivery, MessageDelivery.sent);
    });

    test('one written while another is on its way goes too', () async {
      await messages.load();
      server.holdPost = Completer();

      final first = messages.send(threadId, 'A');
      await pumpEventQueue();
      final second = messages.send(threadId, 'B');
      await pumpEventQueue();
      server.holdPost!.complete();
      await Future.wait([first, second]);

      expect(server.posted.map((each) => each.content), ['sealed:A', 'sealed:B']);
      expect(messages.thread(threadId).messages.map((each) => each.delivery), everyElement(MessageDelivery.sent));
    });

    test('one a read placed while it was on its way keeps that place', () async {
      server.items = [_item('a', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      server.holdPost = Completer();

      final sending = messages.send(threadId, 'mine');
      await pumpEventQueue();
      final theirs = _item('b', cursor: 'c3');
      server.items = [_item('a', cursor: 'c1'), _mine('mine-0', 'mine', cursor: 'c2'), theirs];
      await messages.pull(threadId);
      server.holdPost!.complete();
      await sending;

      final held = store.items[me]!.firstWhere((each) => each.item.id == 'mine-0');
      expect((held.item.cursor, held.position, held.pending), ('c2', 1, false));
      expect(messages.thread(threadId).messages.map((each) => each.text), ['a', 'mine', 'b']);
    });

    test("one that can't be sealed throws, and nothing is kept", () async {
      await messages.load();
      cipher.sealFails = StateError('device keys are off');
      messages.keepDraft(threadId, 'words');

      await expectLater(messages.send(threadId, 'words'), throwsStateError);

      expect(store.items[me] ?? [], isEmpty);
      expect(messages.draft(threadId), 'words');
    });
  });

  test('a sign-out forgets the inbox, the threads and the drafts', () async {
    await messages.load();
    messages.keepDraft(threadId, 'unsent');

    messages.onSignOut();

    expect(messages.threads, isEmpty);
    expect(messages.draft(threadId), '');
    expect(messages.userId, isNull);
  });
}

ThreadItem _item(String text, {String sender = 'whiskers', String? cursor, DateTime? createdAt}) {
  final at = createdAt ?? DateTime.utc(2026, 11, 12, 8);
  return ThreadItem(
    id: 'item-$text',
    threadId: 't1',
    senderId: sender,
    kind: 'message',
    content: 'sealed:$text',
    commitment: 'c',
    tag: 'tag',
    tagKey: 'k',
    at: at,
    createdAt: at,
    cursor: cursor,
  );
}

ThreadItem _mine(String id, String text, {String? cursor}) {
  final at = DateTime.utc(2026, 11, 12, 9);
  return ThreadItem(
    id: id,
    threadId: 't1',
    senderId: 'muffin',
    kind: 'message',
    content: 'sealed:$text',
    commitment: 'c',
    tag: 'tag',
    tagKey: 'k',
    at: at,
    createdAt: at,
    cursor: cursor,
  );
}

/// What a request that never reached the server throws.
class _Unreachable implements Exception {
  const new();
}

/// heart-api's thread routes, in memory: items in stored order, newest
/// first without a cursor, and a page cursor only when more follow.
class _Server implements RemoteThreadService {
  final calls = <String>[];
  List<Thread> threads = [];
  List<ThreadItem> items = [];
  final posted = <({String id, String content, String? subjectId})>[];
  int pageSize = 50;
  Object? failNextPost;
  Map<String, Object>? refusePost;

  /// Holds each post, and each page once read, until completed.
  Completer<void>? holdPost;
  Completer<void>? holdPage;

  @override
  Future<Thread> openThread(String connectionId) async {
    calls.add('open $connectionId');
    final thread = Thread(id: 'thread-$connectionId', connectionId: connectionId, otherId: 'whiskers');
    threads = [...threads, thread];
    return thread;
  }

  @override
  Future<List<Thread>> getThreads() async {
    calls.add('threads');
    return threads;
  }

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
    calls.add('post $threadId $id');
    await holdPost?.future;
    posted.add((id: id, content: content, subjectId: subjectId));
    if (failNextPost case final Object failure) {
      failNextPost = null;
      throw failure;
    }
    if (refusePost case final Map<String, Object> refusal) throw refusal;
    return ThreadItem(
      id: id,
      threadId: threadId,
      senderId: 'muffin',
      kind: 'message',
      subjectType: subjectType,
      subjectId: subjectId,
      content: content,
      commitment: commitment,
      tag: 'tag',
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
    final from = switch ((since, before)) {
      (final String since, _) => 'since $since',
      (_, final String before) => 'before $before',
      _ => 'newest',
    };
    calls.add('items $threadId $from');
    final size = min(limit ?? pageSize, pageSize);
    final more = switch (since) {
      final String since => items.skipWhile((each) => each.cursor != since).skip(1).toList(),
      null => switch (before) {
        final String before => items.takeWhile((each) => each.cursor != before).toList().reversed.toList(),
        null => items.reversed.toList(),
      },
    };
    final page = more.take(size).toList();
    await holdPage?.future;
    return (
      items: page,
      cursor: switch (more.length > size) {
        true => page.last.cursor,
        false => null,
      },
    );
  }

  @override
  Future<void> markThreadRead(String threadId, String cursor) async => calls.add('read $threadId $cursor');

  /// What a clear stamps on the thread.
  DateTime? clearedAt;
  final reports = <({String reportedId, String reason, List<ReportedMessage> reported})>[];

  @override
  Future<void> clearThread(String threadId) async {
    calls.add('clear $threadId');
    items = [];
    threads = [
      for (final each in threads)
        switch (each.id == threadId) {
          true => Thread(
            id: each.id,
            connectionId: each.connectionId,
            otherId: each.otherId,
            otherName: each.otherName,
            clearedAt: clearedAt,
            clearedBy: 'muffin',
          ),
          false => each,
        },
    ];
  }

  @override
  Future<void> fileReport({
    required String reportedId,
    String? connectionId,
    required String reason,
    List<ReportedMessage> messages = const [],
  }) async {
    reports.add((reportedId: reportedId, reason: reason, reported: messages));
  }
}

class _Store implements LocalThreadService {
  final threads = <String, List<Thread>>{};
  final items = <String, List<StoredItem>>{};

  @override
  Future<List<Thread>> getThreads(String userId) async => [...?threads[userId]];

  @override
  Future<void> storeThreads(String userId, Iterable<Thread> threads) async => this.threads[userId] = [...threads];

  @override
  Future<void> storeThread(String userId, Thread thread) async {
    threads[userId] = [...?threads[userId]?.where((each) => each.id != thread.id), thread];
  }

  @override
  Future<List<StoredItem>> getThreadItems(String userId, String threadId) async {
    final held = [...?items[userId]?.where((each) => each.item.threadId == threadId)];
    final placed = held.where((each) => each.position != null).toList()
      ..sort((a, b) => a.position!.compareTo(b.position!));
    return [...placed, ...held.where((each) => each.position == null)];
  }

  @override
  Future<void> deleteThreadItems(String userId, Iterable<String> itemIds) async {
    items[userId]?.removeWhere((each) => itemIds.contains(each.item.id));
  }

  @override
  Future<void> storeThreadItems(String userId, Iterable<StoredItem> stored) async {
    final held = items[userId] ??= [];
    for (final each in stored) {
      held
        ..removeWhere((old) => old.item.id == each.item.id)
        ..add(each);
    }
  }
}

/// Sealing that shows its work: `sealed:<words>`, opened by taking the
/// prefix off.
class _Cipher implements ThreadCipher {
  final _keys = StreamController<String>.broadcast();
  final shares = <String>[];
  final missing = <String>{};
  Object? shareFails;
  Object? sealFails;

  /// Threads whose key waits in the queue: [receive] takes them.
  Set<String> queued = {};
  int receives = 0;

  void arrive(String threadId) => _keys.add(threadId);

  @override
  Future<void> receive() async {
    receives++;
    if (queued.isEmpty) return;
    missing.clear();
    for (final each in queued) {
      arrive(each);
    }
    queued = {};
  }

  void dispose() => _keys.close();

  @override
  Stream<String> get threadKeys => _keys.stream;

  @override
  Future<SealedMessage> seal(String threadId, String text) async {
    if (sealFails case final Object failure) throw failure;
    return (content: 'sealed:$text', commitment: 'c');
  }

  @override
  Future<void> share(String threadId, {required String userId, String? fingerprint}) async {
    if (shareFails case final Object failure) throw failure;
    shares.add('$threadId $userId $fingerprint');
  }

  @override
  Future<List<OpenedMessage>> open(String threadId, List<ThreadCiphertext> items) async {
    return [
      for (final each in items)
        switch (each.content.split(':')) {
          ['sealed', final String text] when !missing.contains(text) => Opened(text: text, frankingKey: 'f'),
          ['sealed', _] => const Locked(),
          _ => const Refused(),
        },
    ];
  }
}
