import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Rows written to the local mirror are built from model code, and those models
/// arrive from another repository by git dependency. A field added there shows
/// up as a key with no column behind it, and SQLite rejects the whole statement
/// with `no such column`.
///
/// That is not a contained failure. `storeExercises` throwing takes
/// `Exercises.init` down with it, and init swallows the error without ever
/// setting `isInitialized` — so the catalogue sits loaded in memory while the
/// app waits on a spinner that never resolves. A missing migration bricked
/// start-up, which is why the write now narrows itself to the schema instead.
void main() {
  late Database db;
  late LocalDatabase local;

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  /// The shape of the problem: a column the app's schema does not have yet.
  Future<void> dropHealthColumn() => db.execute('ALTER TABLE exercises DROP COLUMN health');

  test('a model field with no column does not fail the write', () async {
    await dropHealthColumn();

    final swimming = Exercise.fromJson({
      'id': 'id-swimming',
      'name': 'Swimming',
      'category': 'Cardio',
      'target': 'Cardio',
      'archived': false,
      'health': {'activity': 'swimming'},
    });

    // Before the fix this threw `no such column: health`, and every exercise
    // went unwritten with it.
    await local.storeExercises([swimming]);

    final (_, stored) = await local.getExercises();
    expect(stored.single.name, 'Swimming');
  });

  test('the rest of the row still lands', () async {
    await dropHealthColumn();

    final swimming = Exercise.fromJson({
      'id': 'id-swimming',
      'name': 'Swimming',
      'category': 'Cardio',
      'target': 'Cardio',
      'archived': false,
      'health': {'activity': 'swimming'},
    });

    await local.storeExercises([swimming]);
    final (_, stored) = await local.getExercises();

    // Only the unbacked key is dropped; everything with a column persists.
    expect(stored.single.category, Category.cardio);
    expect(stored.single.target, Target.cardio);
    // And the reader falls back exactly as it does for any unannotated
    // exercise, rather than reporting a swim as strength training.
    expect(stored.single.activity, HealthActivity.other);
  });

  test('with the column present the value is persisted', () async {
    final swimming = Exercise.fromJson({
      'id': 'id-swimming',
      'name': 'Swimming',
      'category': 'Cardio',
      'target': 'Cardio',
      'archived': false,
      'health': {'activity': 'swimming'},
    });

    await local.storeExercises([swimming]);
    final (_, stored) = await local.getExercises();

    expect(stored.single.activity, HealthActivity.swimming);
  });
}
