import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// "Not today" in the mirror (#312): a skip is a mark in its program's
/// position, outlives the program and the session it names, and keeps its
/// weather as it came.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';

  TrainingSkip skip(String id, {String? templateId = 't2', String? programId = 'p1', DateTime? at}) {
    return TrainingSkip(
      id: id,
      at: at ?? DateTime.utc(2026, 10, 3, 7),
      reason: 'tired',
      weather: Weather(pressure: 1009, pressureTrend: -4),
      templateId: templateId,
      programId: programId,
    );
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await local.storeProgram(
      Program(id: 'p1', name: 'Getting stronger', sessions: const ['t1', 't2'], createdAt: DateTime.utc(2026, 10)),
      userId,
    );
  });

  tearDown(() => db.close());

  test('a skip comes back as it was stored, weather and all', () async {
    await local.storeSkip(skip('s1'), userId);

    final [read] = await local.getSkips(userId);

    expect(read.toMap(), skip('s1').toMap());
  });

  test("a program's marks are its finished workouts and its skips, in time order", () async {
    await local.storeWorkoutHistory([
      Workout.fromJson({
        'id': 'w1',
        'start': '2026-10-02T08:00:00.000Z',
        'end': '2026-10-02T09:00:00.000Z',
        'templateId': 't1',
        'programId': 'p1',
      }),
    ], userId);
    await local.storeSkip(skip('s1'), userId);
    await local.storeSkip(skip('s2', programId: 'p9'), userId);

    final marks = await local.getProgramMarks(userId, 'p1');

    expect(marks.map((mark) => (mark.templateId, mark.at, mark.isWorkout)), [
      ('t1', DateTime.utc(2026, 10, 2, 8), true),
      ('t2', DateTime.utc(2026, 10, 3, 7), false),
    ]);
  });

  test("a full read replaces the user's skips, and only theirs", () async {
    await local.storeSkip(skip('s1'), userId);
    await local.storeSkip(skip('s9'), 'someone-else');

    await local.storeSkips([skip('s2')], userId);

    expect((await local.getSkips(userId)).map((each) => each.id), ['s2']);
    expect((await local.getSkips('someone-else')).map((each) => each.id), ['s9']);
  });

  test('a skip outlives its program and its session, as the server keeps it', () async {
    await local.storeSkip(skip('s1'), userId);
    await local.storeSkip(skip('s2', templateId: 't1'), userId);
    await local.storeTemplates([
      Template.fromJson({'id': 't1', 'name': 'A', 'order': 0, 'programId': 'p1'}),
    ], userId: userId);

    await local.deleteProgram('p1', keepTemplates: false);

    final skips = await local.getSkips(userId);
    expect(skips.map((each) => (each.id, each.templateId, each.programId)), [
      ('s1', 't2', null),
      ('s2', null, null),
    ]);
  });

  test('deleting one goes', () async {
    await local.storeSkip(skip('s1'), userId);

    await local.deleteSkip('s1');

    expect(await local.getSkips(userId), isEmpty);
  });
}
