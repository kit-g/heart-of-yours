import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';

import 'real_database.dart';
import 'utils.dart';

void main() {
  test('session notes survive restart, full replacement, and clearing independently of pins', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final local = await LocalDatabase.init(other: db);
    final ex = exercise();
    await local.storeExercises([ex]);
    final workout = Workout(name: 'Notes');
    final entry = workout.add(ex)..note = 'Pause at the bottom';
    await local.startWorkout(workout, 'anonymous');
    await local.setExerciseNote(ex.id, 'anonymous', 'Slow eccentric');
    final reopened = await LocalDatabase.init(other: db);
    expect((await reopened.getActiveWorkout('anonymous'))!.first.note, entry.note);
    await reopened.setWorkoutExerciseNote(entry.id, 'One hand at a time');
    expect((await reopened.getActiveWorkout('anonymous'))!.first.note, 'One hand at a time');
    entry.note = 'Updated session';
    entry.first.isCompleted = true;
    workout.finish(DateTime.now());
    await local.finishWorkout(workout, 'anonymous');
    expect((await local.getWorkoutHistory('anonymous'))!.single.first.note, 'Updated session');
    await local.setWorkoutExerciseNote(entry.id, null);
    expect((await local.getWorkoutHistory('anonymous'))!.single.first.note, isNull);
    expect(await local.getExerciseNotes('anonymous'), {ex.id: 'Slow eccentric'});
  });

  test('pins preserve other preferences, rekey and merge before replay, and erase with the user', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final local = await LocalDatabase.init(other: db);
    final ex = exercise();
    final merged = exercise(id: 'merged');
    await local.storeExercises([ex, merged]);
    await local.setExerciseUnit(exerciseName: ex.id, userId: 'anonymous', unit: .imperial);
    await local.setExerciseNote(ex.id, 'anonymous', 'Pause');
    await local.recordUpsync('account', (resource: 'note', id: ex.id, outcome: 'created'));
    await local.rekeyUser('anonymous', 'account');
    expect(await local.upsyncLedger('account'), isEmpty);
    await local.mergeExercise('account', from: ex.id, to: merged.id);
    expect(await local.getExerciseNotes('account'), {merged.id: 'Pause'});
    expect(await local.getExerciseNotes('anonymous'), isEmpty);
    await local.setExerciseNote(merged.id, 'account', null);
    expect(await local.getExerciseNotes('account'), isEmpty);
    expect(await local.getExerciseUnits('account'), {merged.id: MeasurementUnit.imperial});
    await local.setExerciseNote(merged.id, 'account', 'Again');
    await local.eraseUser('account');
    expect(await local.getExerciseNotes('account'), isEmpty);
  });
}
