import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'test_utils.dart';

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

  group('keys asked for (#556)', () {
    test("the other person's device is answered, checked against their fingerprint", () async {
      await messages.load();

      expect(await cipher.request(threadId, coach), isTrue);

      expect(cipher.answers, ['t1 tablet print-c1']);
    });

    test("the account's own device is answered with no fingerprint: its own devices are checked by trust", () async {
      await messages.load();

      expect(await cipher.request(threadId, me), isTrue);

      expect(cipher.answers, ['t1 tablet null']);
    });

    test('someone not in the thread, or a thread this account does not hold, is turned down for good', () async {
      await messages.load();

      expect(await cipher.request(threadId, 'stranger'), isTrue);
      expect(await cipher.request('elsewhere', coach), isTrue);

      expect(cipher.answers, isEmpty);
    });

    test('a conversation whose connection ended, or that takes nothing more, answers nothing', () async {
      server.threads = [Thread(id: threadId, otherId: coach, otherName: 'Whiskers')];
      await messages.load();

      expect(await cipher.request(threadId, coach), isTrue);

      expect(cipher.answers, isEmpty);
    });

    test('a second request from the same device within a minute is the first one', () async {
      await messages.load();

      await cipher.request(threadId, coach);
      await cipher.request(threadId, coach);
      await cipher.request(threadId, coach, deviceId: 'phone');

      expect(cipher.answers, ['t1 tablet print-c1', 't1 phone print-c1']);
    });

    test('one that arrives before the inbox was read finds the thread on the device', () async {
      store.threads[me] = [Thread(id: threadId, connectionId: 'c1', otherId: coach)];

      expect(await cipher.request(threadId, coach), isTrue);

      expect(cipher.answers, ['t1 tablet print-c1']);
    });

    test('with no account yet, or an answer that fails, the request is kept for later', () async {
      messages.userId = null;
      expect(await cipher.request(threadId, coach), isFalse);

      messages.userId = me;
      await messages.load();
      cipher.answerFails = StateError('offline');
      expect(await cipher.request(threadId, coach), isFalse);
      expect(errors, [isA<StateError>()]);

      cipher.answerFails = null;
      expect(await cipher.request(threadId, coach), isTrue, reason: 'a failure holds nothing back');
      expect(cipher.answers, ['t1 tablet print-c1']);
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

    test('one still locked once the queue is read is asked for, and nothing opened is', () async {
      server.items = [_item('open', cursor: 'c1'), _item('stuck', cursor: 'c2')];
      cipher.missing.add('stuck');
      await messages.load();

      await messages.open(threadId);

      await pumpEventQueue();
      expect(cipher.asks, ['t1 item-stuck print-c1']);
    });

    test('nothing locked asks for nothing', () async {
      server.items = [_item('open', cursor: 'c1')];
      await messages.load();

      await messages.open(threadId);

      expect(cipher.asks, isEmpty);
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

    test('a deletion the server took clears the device even when the inbox can\'t be read after it', () async {
      server.items = [_item('a', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      server.failThreads = const _Unreachable();

      await messages.clear(threadId);

      expect(messages.thread(threadId).messages, isEmpty);
      expect(store.items[me], isEmpty);
      expect(messages.lookup(threadId)!.clearedBy, me);
    });

    test('what still holds something: a message since the last deletion, under a connection', () async {
      server.threads = [
        ...server.threads,
        Thread(id: 'empty', connectionId: 'c2', otherId: coach),
        Thread(id: 'orphan', otherId: coach, lastAt: DateTime.utc(2026, 11, 11)),
      ];

      await messages.load();

      expect(messages.holding.map((each) => each.id), [threadId]);
    });

    test('deleted here, a conversation holds nothing, even when the inbox can\'t be read after it', () async {
      await messages.load();
      server.failThreads = const _Unreachable();

      await messages.clear(threadId);

      expect(messages.lookup(threadId)!.lastAt, isNull);
      expect(messages.holding, isEmpty);
      expect(store.threads[me]!.single.lastAt, isNull, reason: 'kept that way on the device');
    });

    test('written in after a deletion, it holds something again, before the server says so', () async {
      await messages.load();
      await messages.clear(threadId);
      access.account = false;

      await messages.send(threadId, 'one more thing');

      expect(messages.holding.map((each) => each.id), [threadId]);
      expect(messages.lookup(threadId)!.lastAt, DateTime.utc(2026, 11, 12, 9));
    });

    test('deleting them all goes at once, reads the inbox once, and counts what failed', () async {
      server.threads = [
        ...server.threads,
        Thread(id: 't2', connectionId: 'c2', otherId: 'biscuit', lastAt: DateTime.utc(2026, 11, 11)),
        Thread(id: 't3', connectionId: 'c3', otherId: 'pickle', lastAt: DateTime.utc(2026, 11, 10)),
      ];
      server.failClear = {'t2'};
      await messages.load();
      server.calls.clear();

      final failed = await messages.clearAll();

      expect(failed, 1);
      expect(errors, hasLength(1));
      expect(
        server.calls.where((each) => each.startsWith('clear')),
        unorderedEquals(['clear t1', 'clear t2', 'clear t3']),
      );
      expect(server.calls.where((each) => each == 'threads'), hasLength(1));
      expect(messages.holding.map((each) => each.id), ['t2']);
    });

    test('a read under way when the conversation was deleted brings none of it back', () async {
      server.items = [_item('a', cursor: 'c1')];
      await messages.load();
      await messages.open(threadId);
      server.items = [_item('a', cursor: 'c1'), _item('b', cursor: 'c2')];
      server.holdPage = Completer();

      final reading = messages.pull(threadId);
      await pumpEventQueue();
      server.clearedAt = DateTime.utc(2026, 11, 12, 9);
      final clearing = messages.clear(threadId);
      await pumpEventQueue();
      server.holdPage!.complete();
      await Future.wait([reading, clearing]);

      expect(store.items[me], isEmpty);
      expect(messages.thread(threadId).messages, isEmpty);
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

      messages.writeAbout('c1', const MessageSubject(.workout, 'w1'));
      await messages.send(threadId, 'my knee');

      expect(cipher.shares, ['t1 $coach print-c1']);
      expect(server.posted.single, (id: 'mine-0', content: 'sealed:my knee', subjectId: 'w1'));
      final sent = messages.thread(threadId).messages.single;
      expect((sent.text, sent.mine, sent.delivery), ('my knee', true, MessageDelivery.sent));
    });

    test('what a message is about goes with the next one written to that person, then clears', () async {
      await messages.load();
      messages.writeAbout('c1', const MessageSubject(.exerciseSet, 's3'));
      expect(messages.about('c1'), const MessageSubject(.exerciseSet, 's3'));

      final first = messages.send(threadId, 'that third set');
      // a second, sent while the first is still on its way, is about nothing
      final second = messages.send(threadId, 'and the rest');
      await (first, second).wait;

      expect(server.posted.map((each) => each.subjectId), ['s3', null]);
      expect(messages.thread(threadId).messages.first.subject, const MessageSubject(.exerciseSet, 's3'));
      expect(messages.about('c1'), isNull, reason: 'said: the next one is about nothing in particular');
    });

    test('a message that could not be sealed keeps what it was about', () async {
      await messages.load();
      messages.writeAbout('c1', const MessageSubject(.workout, 'w1'));
      cipher.sealFails = StateError('device keys are off');

      await expectLater(messages.send(threadId, 'my knee'), throwsStateError);

      expect(messages.about('c1'), const MessageSubject(.workout, 'w1'));
    });

    test("a subject this build doesn't know reads as none", () {
      expect(MessageSubject.of('skip', 'k1'), isNull);
      expect(MessageSubject.of('workout', ''), isNull);
      expect(MessageSubject.of('exercise_set', 's1'), const MessageSubject(.exerciseSet, 's1'));
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
      server.refusePost = refusedAs({'error': 'forbidden', 'code': 'thread_closed', 'reason': '…'}, status: 403);

      await messages.send(threadId, 'still there?');

      final thread = messages.thread(threadId);
      expect(thread.closed, isTrue);
      expect(thread.messages.single.delivery, MessageDelivery.closed);
      expect(errors, isEmpty);
    });

    testWidgets('too many at once waits as long as the server says, then goes', (tester) async {
      // the test's fake clock: the wait passes without real seconds
      await messages.load();
      server.refusePost = refusedAs({
        'error': 'too many requests',
        'code': 'rate_limited',
        'retryAfter': 30,
      }, status: 429);

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

  group('analytics (#568)', () {
    late ReportedAnalytics reported;

    setUp(() {
      reported = ReportedAnalytics();
      messages = Messages(
        service: server,
        local: store,
        cipher: cipher,
        remote: access,
        onError: (error, {stacktrace}) => errors.add(error),
        analytics: Analytics(service: reported),
        roleFor: (thread) => thread.connectionId == 'c1' ? .student : null,
        newId: () => 'mine-${ids++}',
        now: () => DateTime.utc(2026, 11, 12, 9),
      )..userId = me;
    });

    test(
      'a message counts once it is sealed and kept, not when the server has it, and one never kept not at all',
      () async {
        await messages.load();
        access.account = false;

        await messages.send(threadId, 'later');
        expect(server.posted, isEmpty);
        expect(reported.events.map((each) => each.$2), [
          {'role': 'student'},
        ]);

        cipher.sealFails = StateError('device keys are off');
        await expectLater(messages.send(threadId, 'never'), throwsStateError);
        expect(reported.names, ['message_sent'], reason: 'the words never left the caller');
      },
    );

    test('each conversation deleted counts once the server took it, the account deletion\'s among them', () async {
      server.threads = [
        ...server.threads,
        Thread(id: 't2', connectionId: 'c2', otherId: 'biscuit', lastAt: DateTime.utc(2026, 11, 11)),
        Thread(id: 't3', connectionId: 'c3', otherId: 'pickle', lastAt: DateTime.utc(2026, 11, 10)),
      ];
      server.failClear = {'t2'};
      await messages.load();

      await messages.clearAll();

      expect(reported.names, ['conversation_deleted', 'conversation_deleted']);
      expect(
        reported.events.map((each) => each.$2),
        unorderedEquals([
          {'role': 'student'},
          isEmpty,
        ]),
      );
    });

    test("a report answers how many messages went with it: the other person's, opened, alone", () async {
      server.items = [
        _item('rude', cursor: 'c1'),
        _item('mine', sender: me, cursor: 'c2'),
      ];
      await messages.load();
      await messages.open(threadId);
      final thread = messages.lookup(threadId)!;

      final all = await messages.report(thread, .harassment, messages: messages.thread(threadId).messages);
      final mineAlone = await messages.report(
        thread,
        .harassment,
        messages: messages.thread(threadId).messages.where((each) => each.mine),
      );

      expect((all, mineAlone), (1, 0));
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
  ServerRefusal? refusePost;

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

  Object? failThreads;

  @override
  Future<List<Thread>> getThreads() async {
    calls.add('threads');
    if (failThreads case final Object failure) throw failure;
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
    if (refusePost case final ServerRefusal refusal) throw refusal;
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

  /// Threads whose clear never reaches the server.
  Set<String> failClear = {};
  final reports = <({String reportedId, String reason, List<ReportedMessage> reported})>[];

  @override
  Future<void> clearThread(String threadId) async {
    calls.add('clear $threadId');
    if (failClear.contains(threadId)) throw const _Unreachable();
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

  /// What [ask] was asked for: `<thread> <item ids> <fingerprint>`.
  final asks = <String>[];

  /// Requests answered: `<thread> <device> <fingerprint>`.
  final answers = <String>[];
  Object? answerFails;

  KeyRequestHandler? onRequest;
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

  /// A request from [userId]'s [deviceId], as the cipher hands it over:
  /// whether it was dealt with.
  Future<bool> request(String threadId, String userId, {String deviceId = 'tablet'}) {
    return onRequest!((threadId: threadId, userId: userId, deviceId: deviceId, sessions: {'s1'}));
  }

  void dispose() => _keys.close();

  @override
  set onKeyRequest(KeyRequestHandler? handler) => onRequest = handler;

  @override
  Future<void> ask(String threadId, List<ThreadCiphertext> items, {String? fingerprint}) async {
    asks.add('$threadId ${items.map((each) => each.id).join(',')} $fingerprint');
  }

  @override
  Future<void> answer(KeyRequest request, {String? fingerprint}) async {
    if (answerFails case final Object failure) throw failure;
    answers.add('${request.threadId} ${request.deviceId} $fingerprint');
  }

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
