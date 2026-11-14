import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// A coach's notes (#556), kept as ciphertext so they open offline.
void main() {
  late Database db;
  late LocalDatabase local;

  const user = 'muffin';

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  CoachNote note(String id, {String content = 'n1.k.sealed', int minute = 0}) {
    return CoachNote(
      id: id,
      connectionId: 'c1',
      content: content,
      updatedAt: DateTime.utc(2026, 11, 14, 9, minute),
    );
  }

  test('notes come back last edited first, with where each stands', () async {
    await local.storeCoachNotes(user, [
      (note: note('a', minute: 1), pending: false, deleted: false),
      (note: note('b', minute: 2), pending: true, deleted: false),
      (note: note('c', minute: 3), pending: true, deleted: true),
    ]);

    final stored = await local.getCoachNotes(user);

    expect([for (final each in stored) each.note.id], ['c', 'b', 'a']);
    expect([for (final each in stored) (each.pending, each.deleted)], [(true, true), (true, false), (false, false)]);
    expect(stored.last.note.connectionId, 'c1');
    expect(stored.last.note.updatedAt, DateTime.utc(2026, 11, 14, 9, 1));
  });

  test('another account\'s notes stay out', () async {
    await local.storeCoachNotes('whiskers', [(note: note('a'), pending: false, deleted: false)]);

    expect(await local.getCoachNotes(user), isEmpty);
  });

  test('the server\'s notes replace what was sent, and leave what waits', () async {
    await local.storeCoachNotes(user, [
      (note: note('gone'), pending: false, deleted: false),
      (note: note('edited', content: 'mine'), pending: true, deleted: false),
      (note: note('deleting'), pending: true, deleted: true),
    ]);

    await local.replaceCoachNotes(user, [
      note('edited', content: 'theirs'),
      note('deleting'),
      note('new'),
    ]);

    final stored = {for (final each in await local.getCoachNotes(user)) each.note.id: each};
    expect(stored.keys, unorderedEquals(['edited', 'deleting', 'new']));
    expect(stored['edited']!.note.content, 'mine');
    expect(stored['edited']!.pending, isTrue);
    expect(stored['deleting']!.deleted, isTrue);
    expect(stored['new']!.pending, isFalse);
  });

  test('a note deleted for good is forgotten', () async {
    await local.storeCoachNotes(user, [(note: note('a'), pending: true, deleted: true)]);

    await local.deleteCoachNote(user, 'a');

    expect(await local.getCoachNotes(user), isEmpty);
  });

  test('erasing the account takes its notes', () async {
    await local.storeCoachNotes(user, [(note: note('a'), pending: false, deleted: false)]);

    await local.eraseUser(user);

    expect(await local.getCoachNotes(user), isEmpty);
  });
}
