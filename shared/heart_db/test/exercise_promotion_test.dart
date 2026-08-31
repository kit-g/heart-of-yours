// An exercise can change hands: a user's custom gets promoted into the
// shared catalog, and the next sync serves the same name as a stock
// exercise. The upsert must shed the old owner along with flipping `own`,
// or the conflict-update lands on own = 0 with a stale user_id and trips
// CHECK (own = 1 OR user_id IS NULL) — and that is not a contained failure:
// `storeExercises` throwing takes the whole catalog sync down with it.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

void main() {
  late Database db;
  late LocalDatabase local;

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  Exercise landminePress({required bool own}) {
    return Exercise.fromJson({
      'id': 'id-landmine-press',
      'name': 'Landmine Press',
      'category': 'Barbell',
      'target': 'Shoulders',
      'archived': false,
      'own': own,
    });
  }

  test('a custom promoted into the catalog sheds its owner on the upsert', () async {
    await local.storeExercises([landminePress(own: true)], userId: 'u1');

    final before = await db.query('exercises', where: 'name = ?', whereArgs: ['Landmine Press']);
    expect(before.single['own'], 1);
    expect(before.single['user_id'], 'u1');

    // the next sync serves the same name from the shared library
    await local.storeExercises([landminePress(own: false)], userId: 'u1');

    final after = await db.query('exercises', where: 'name = ?', whereArgs: ['Landmine Press']);
    expect(after.single['own'], 0);
    expect(after.single['user_id'], isNull);
  });

  test('a custom staying a custom keeps its owner across re-syncs', () async {
    await local.storeExercises([landminePress(own: true)], userId: 'u1');
    await local.storeExercises([landminePress(own: true)], userId: 'u1');

    final rows = await db.query('exercises', where: 'name = ?', whereArgs: ['Landmine Press']);
    expect(rows.single['own'], 1);
    expect(rows.single['user_id'], 'u1');
  });

  test('the content slug round-trips, and sheds like the owner does', () async {
    Exercise benchPress({String? key}) {
      return Exercise.fromJson({
        'id': 'id-bench-press',
        'key': ?key,
        'name': 'Bench Press (Barbell)',
        'category': 'Barbell',
        'target': 'Chest',
        'archived': false,
      });
    }

    await local.storeExercises([benchPress(key: 'bench-press-barbell')], userId: 'u1');

    final (_, stored) = await local.getExercises(userId: 'u1');
    expect(stored.single.key, 'bench-press-barbell');

    // `toMap()` omits a null slug, and the conflict-update leaves absent keys
    // stale — the same mechanism as user_id above; the unconditional row
    // write is what clears it
    await local.storeExercises([benchPress()], userId: 'u1');

    final (_, restored) = await local.getExercises(userId: 'u1');
    expect(restored.single.key, isNull);
  });
}
