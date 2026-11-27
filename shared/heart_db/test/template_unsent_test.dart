import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Against a real in-memory SQLite: what a template owes the server, and who
/// assigned it, are columns a stub cannot hold (#448).
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';

  Template template({String id = 't1', String name = 'Push', Map? assignedBy}) {
    return Template.fromJson({
      'id': id,
      'name': name,
      'order': 0,
      'exercises': [],
      'assignedBy': ?assignedBy,
      if (assignedBy != null) 'sourceTemplateId': 'master-1',
      if (assignedBy != null) 'syncEnabled': true,
    });
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  group('who assigned a template', () {
    test('an assigned template read back from the mirror is still assigned', () async {
      await local.storeTemplates(
        [
          template(assignedBy: {'id': 'coach-1', 'username': 'Muffin', 'avatar': 'https://example.com/m.png'}),
        ],
        userId: userId,
      );

      final [read] = (await local.getTemplates(userId)).toList();

      expect(read.isAssigned, isTrue);
      expect(read.assignedBy?.id, 'coach-1');
      expect(read.assignedBy?.name, 'Muffin');
      expect(read.assignedBy?.avatar, 'https://example.com/m.png');
      expect(read.sourceTemplateId, 'master-1');
      expect(read.syncEnabled, isTrue);
    });

    test("the owner's own template reads as nobody's", () async {
      await local.storeTemplates([template()], userId: userId);

      final [read] = (await local.getTemplates(userId)).toList();

      expect(read.isAssigned, isFalse);
      expect(read.sourceTemplateId, isNull);
      expect(read.syncEnabled, isNull);
    });

    test('an edit on the device leaves who assigned it', () async {
      await local.storeTemplates(
        [
          template(assignedBy: {'id': 'coach-1', 'username': 'Muffin'}),
        ],
        userId: userId,
      );

      await local.updateTemplate(template(name: 'Push, heavier'));

      final [read] = (await local.getTemplates(userId)).toList();
      expect(read.name, 'Push, heavier');
      expect(read.assignedBy?.id, 'coach-1');
    });
  });

  group('a change the server has not had', () {
    test('no template owes anything until one is marked', () async {
      await local.storeTemplates([template()], userId: userId);

      expect(await local.getUnsentTemplates(userId), isEmpty);
    });

    test('a marked template comes back with the copy its change started from', () async {
      await local.storeTemplates([template(), template(id: 't2', name: 'Pull')], userId: userId);

      await local.markTemplateUnsent('t1', template());

      final unsent = await local.getUnsentTemplates(userId);
      expect(unsent.keys, ['t1']);
      expect(unsent['t1']?.name, 'Push');
    });

    test('a second change keeps the first base: the server never saw what came between', () async {
      await local.storeTemplates([template()], userId: userId);

      await local.markTemplateUnsent('t1', template());
      await local.markTemplateUnsent('t1', template(name: 'Push, edited once'));

      expect((await local.getUnsentTemplates(userId))['t1']?.name, 'Push');
    });

    test('an edit on the device keeps the mark', () async {
      await local.storeTemplates([template()], userId: userId);
      await local.markTemplateUnsent('t1', template());

      await local.updateTemplate(template(name: 'Push, edited'));

      expect((await local.getUnsentTemplates(userId)).keys, ['t1']);
    });

    test('a store of the row keeps the mark: not every store is the server\'s copy', () async {
      await local.storeTemplates([template(), template(id: 't2', name: 'Pull')], userId: userId);
      await local.markTemplateUnsent('t1', template());

      await local.storeTemplates(
        [template(name: 'Push, filed in a program'), template(id: 't2', name: 'Pull, again')],
        userId: userId,
      );

      final unsent = await local.getUnsentTemplates(userId);
      expect(unsent.keys, ['t1']);
      expect(unsent['t1']?.name, 'Push');
    });

    test('clearing lets it go', () async {
      await local.storeTemplates([template()], userId: userId);
      await local.markTemplateUnsent('t1', template());

      await local.clearTemplateUnsent('t1');

      expect(await local.getUnsentTemplates(userId), isEmpty);
    });

    test('a base that cannot be read is still owed, as null', () async {
      await local.storeTemplates([template()], userId: userId);
      await db.update('templates', {'unsent_base': 'not json'}, where: 'id = ?', whereArgs: ['t1']);

      expect(await local.getUnsentTemplates(userId), {'t1': null});
    });

    test("another account's marks stay its own", () async {
      await local.storeTemplates([template()], userId: 'user-2');
      await local.markTemplateUnsent('t1', template());

      expect(await local.getUnsentTemplates(userId), isEmpty);
    });
  });
}
