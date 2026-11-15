import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// A workout someone's coach logged for them keeps who did (#560), through
/// History's mirror and an edit made here.
void main() {
  late Database db;
  late LocalDatabase local;

  const user = 'muffin';

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  Workout logged({String? by, String? name}) {
    return Workout.fromJson({
      'id': 'w1',
      'name': 'Day B',
      'start': '2026-11-07T20:00:00Z',
      'end': '2026-11-07T21:00:00Z',
      'loggedBy': ?by,
      'loggedByName': ?name,
      'exercises': <Object>[],
    });
  }

  test("History's mirror keeps who logged it", () async {
    await local.storeWorkoutHistory([logged(by: 'whiskers', name: 'Whiskers')], user);

    final [stored] = (await local.getWorkoutHistory(user))!.toList();
    expect((stored.loggedBy, stored.loggedByName), ('whiskers', 'Whiskers'));
  });

  test('a copy that leaves it out keeps it', () async {
    await local.storeWorkoutHistory([logged(by: 'whiskers', name: 'Whiskers')], user);

    await local.storeWorkoutHistory([logged()], user);

    final [stored] = (await local.getWorkoutHistory(user))!.toList();
    expect(stored.loggedByName, 'Whiskers');
  });
}
