import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Coaching messages (#556): the inbox, and each thread's ciphertext, kept
/// for a thread that opens offline.
void main() {
  late Database db;
  late LocalDatabase local;

  const user = 'muffin';

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  ThreadItem item(String id, {String thread = 't1', DateTime? at, String? cursor}) {
    final when = at ?? DateTime.utc(2026, 11, 12, 9);
    return ThreadItem(
      id: id,
      threadId: thread,
      senderId: 'whiskers',
      kind: 'message',
      subjectType: 'workout',
      subjectId: 'w1',
      content: 'm1.session.$id',
      commitment: 'c-$id',
      tag: 'tag-$id',
      tagKey: 'k2026a',
      at: when,
      createdAt: when.add(const Duration(seconds: 1)),
      cursor: cursor,
    );
  }

  test('the inbox is replaced whole, newest first, and kept per account', () async {
    await local.storeThreads(user, [
      Thread(id: 'old', otherName: 'Whiskers', lastAt: DateTime.utc(2026, 11, 1)),
      Thread(id: 'new', otherName: 'Biscuit', unread: 2, lastAt: DateTime.utc(2026, 11, 10)),
    ]);
    await local.storeThreads('someone-else', [Thread(id: 'theirs')]);

    expect((await local.getThreads(user)).map((each) => each.id), ['new', 'old']);
    expect((await local.getThreads(user)).first.unread, 2);

    await local.storeThreads(user, [Thread(id: 'new', clearedAt: DateTime.utc(2026, 11, 11), clearedBy: 'whiskers')]);

    final [thread] = await local.getThreads(user);
    expect((thread.id, thread.clearedBy, thread.clearedAt), ('new', 'whiskers', DateTime.utc(2026, 11, 11)));
  });

  test("items come back in the server's order, then those not sent yet", () async {
    await local.storeThreadItems(user, [
      (item: item('pending', at: DateTime.utc(2026, 11, 12, 8)), position: null, pending: true),
      (item: item('second', cursor: 'c2'), position: 1, pending: false),
      (item: item('first', cursor: 'c1', at: DateTime.utc(2026, 11, 12, 10)), position: 0, pending: false),
      (item: item('elsewhere', thread: 't2'), position: 0, pending: false),
    ]);

    final items = await local.getThreadItems(user, 't1');

    expect(items.map((each) => each.item.id), ['first', 'second', 'pending']);
    final first = items.first.item;
    expect(
      (first.tag, first.tagKey, first.cursor, first.subjectType, first.subjectId),
      (
        'tag-first',
        'k2026a',
        'c1',
        'workout',
        'w1',
      ),
    );
    expect(items.last.pending, isTrue);
  });

  test('an item stored again takes its place: a sent one replaces its pending self', () async {
    await local.storeThreadItems(user, [(item: item('m1'), position: null, pending: true)]);
    await local.storeThreadItems(user, [(item: item('m1', cursor: 'c1'), position: 5, pending: false)]);

    final [stored] = await local.getThreadItems(user, 't1');

    expect((stored.position, stored.pending, stored.item.cursor), (5, false, 'c1'));
  });

  test('one item can be dropped', () async {
    await local.storeThreadItems(user, [(item: item('m1'), position: null, pending: true)]);

    await local.deleteThreadItem(user, 'm1');

    expect(await local.getThreadItems(user, 't1'), isEmpty);
  });
}
