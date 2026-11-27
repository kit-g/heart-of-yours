import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// What a day looked like when it was set aside (#445): kept once, on the
/// device, and gone with the skip, the account or the health mirror.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';

  SkipSnapshotRow snapshot({int sets = 12, Map<String, double>? body = const {'steps': 4200, 'sleepAsleep': 6.5}}) {
    return (
      takenAt: DateTime.utc(2026, 1, 26, 7),
      training: {
        'lastWorkoutAt': '2026-11-24T18:00:00.000Z',
        'setsWeek': sets,
        'recovering': const ['chest'],
      },
      body: body,
    );
  }

  TrainingSkip skip(String id) => TrainingSkip(id: id, at: DateTime.utc(2026, 11, 26, 7));

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  test('a snapshot comes back as it was taken', () async {
    await local.storeSkipSnapshot('s1', userId, snapshot());

    final read = await local.getSkipSnapshot('s1');

    expect(read?.takenAt, DateTime.utc(2026, 1, 26, 7));
    expect(read?.training, snapshot().training);
    expect(read?.body, {'steps': 4200.0, 'sleepAsleep': 6.5});
    expect(await local.getSkipSnapshot('s2'), isNull);
  });

  test('the first snapshot of a skip is the one kept', () async {
    await local.storeSkipSnapshot('s1', userId, snapshot());
    await local.storeSkipSnapshot('s1', userId, snapshot(sets: 30));

    expect((await local.getSkipSnapshot('s1'))?.training['setsWeek'], 12);
  });

  test('a snapshot with nothing from Health keeps no body', () async {
    await local.storeSkipSnapshot('s1', userId, snapshot(body: const {}));

    expect((await local.getSkipSnapshot('s1'))?.body, isNull);
  });

  test('forgetting the health mirror empties the body and keeps the training', () async {
    await local.storeSkipSnapshot('s1', userId, snapshot());
    await local.storeSkipSnapshot('s9', 'someone-else', snapshot());

    await local.deleteHealthSamples(userId);

    final read = await local.getSkipSnapshot('s1');
    expect(read?.body, isNull);
    expect(read?.training['setsWeek'], 12);
    expect((await local.getSkipSnapshot('s9'))?.body, isNotNull);
  });

  test('a full read of the skips drops the snapshots of those gone, and only those', () async {
    await local.storeSkip(skip('s1'), userId);
    await local.storeSkip(skip('s2'), userId);
    await local.storeSkipSnapshot('s1', userId, snapshot());
    await local.storeSkipSnapshot('s2', userId, snapshot());
    await local.storeSkipSnapshot('s9', 'someone-else', snapshot());
    // taken a moment ago, its skip's row not stored yet: a skip being made
    await local.storeSkipSnapshot('s3', userId, (
      takenAt: DateTime.timestamp(),
      training: snapshot().training,
      body: null,
    ));

    await local.storeSkips([skip('s2')], userId);

    expect(await local.getSkipSnapshot('s1'), isNull);
    expect(await local.getSkipSnapshot('s2'), isNotNull);
    expect(await local.getSkipSnapshot('s3'), isNotNull);
    expect(await local.getSkipSnapshot('s9'), isNotNull);
  });

  test('a snapshot moves with its skip to a new id', () async {
    // a reason given is the same skip stored again under a new id
    await local.storeSkipSnapshot('s1', userId, snapshot());

    await local.moveSkipSnapshot('s1', 's2');

    expect(await local.getSkipSnapshot('s1'), isNull);
    expect((await local.getSkipSnapshot('s2'))?.training['setsWeek'], 12);
  });

  test('deleting a skip leaves its snapshot to whoever took it back', () async {
    await local.storeSkip(skip('s1'), userId);
    await local.storeSkipSnapshot('s1', userId, snapshot());

    await local.deleteSkip('s1');
    expect(await local.getSkipSnapshot('s1'), isNotNull);

    await local.deleteSkipSnapshot('s1');
    expect(await local.getSkipSnapshot('s1'), isNull);
  });

  test('an anonymous session signing in carries its snapshots to the account', () async {
    await local.storeSkipSnapshot('s1', 'anonymous', snapshot());

    await local.rekeyUser('anonymous', userId);
    await local.deleteHealthSamples(userId);

    // under the account now: its health delete reaches it
    expect((await local.getSkipSnapshot('s1'))?.body, isNull);
  });

  test("erasing an account's rows takes its snapshots", () async {
    await local.storeSkipSnapshot('s1', userId, snapshot());
    await local.storeSkipSnapshot('s9', 'someone-else', snapshot());

    await local.eraseUser(userId);

    expect(await local.getSkipSnapshot('s1'), isNull);
    expect(await local.getSkipSnapshot('s9'), isNotNull);
  });
}
