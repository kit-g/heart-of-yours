import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';

import 'real_database.dart';

void main() {
  Exercise own(String name) {
    return Exercise(name: name, category: .barbell, target: .chest, isMine: true);
  }

  test('an unsent edit is marked, survives the row being stored again, and clears (#616)', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final local = await LocalDatabase.init(other: db);
    final (mine, other) = (own('Landmine press'), own('Sled push'));
    await local.storeExercises([mine, other], userId: 'u1');
    expect(await local.getUnsentExerciseEdits('u1'), isEmpty);

    await local.setExerciseEditUnsent(mine.id, 'u1', unsent: true);
    expect(await local.getUnsentExerciseEdits('u1'), {mine.id: false});
    await local.setExerciseEditUnsent(mine.id, 'u1', unsent: true, renamed: true);
    expect(await local.getUnsentExerciseEdits('u1'), {mine.id: true});

    // the store writes the model's keys only, so the mark stays through it
    await local.storeExercises([mine.copyWith(target: .back)], userId: 'u1');
    final reopened = await LocalDatabase.init(other: db);
    expect(await reopened.getUnsentExerciseEdits('u1'), {mine.id: true});
    final (_, stored) = await reopened.getExercises(userId: 'u1');
    expect(stored.firstWhere((each) => each.id == mine.id).target, Target.back);

    await reopened.setExerciseEditUnsent(mine.id, 'u1', unsent: false);
    expect(await reopened.getUnsentExerciseEdits('u1'), isEmpty);
  });

  test('a renamed exercise is read under its new name by the workouts and templates holding it (#616)', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final local = await LocalDatabase.init(other: db);
    final mine = own('Landmine press');
    await local.storeExercises([mine], userId: 'u1');
    final done = Workout(name: 'Done')..add(mine);
    done.first.first.isCompleted = true;
    await local.startWorkout(done, 'u1');
    done.finish(DateTime.now());
    await local.finishWorkout(done, 'u1');
    final active = Workout(name: 'Now')..add(mine);
    await local.startWorkout(active, 'u1');
    final template = Template.empty(id: 'template-1', order: 0)
      ..name = 'Push'
      ..add(mine);
    await local.storeTemplates([template], userId: 'u1');

    final renamed = Exercise.fromJson({...mine.toMap(), 'name': 'Half-kneeling press'});
    await local.storeExercises([renamed], userId: 'u1');

    expect((await local.getWorkout('u1', done.id))!.single.exercise.name, 'Half-kneeling press');
    expect((await local.getActiveWorkout('u1'))!.single.exercise.name, 'Half-kneeling press');
    expect((await local.getTemplates('u1')).single.single.exercise.name, 'Half-kneeling press');
  });

  test("another account's exercise is never marked", () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final local = await LocalDatabase.init(other: db);
    final mine = own('Landmine press');
    await local.storeExercises([mine], userId: 'u1');
    await local.setExerciseEditUnsent(mine.id, 'u2', unsent: true);
    expect(await local.getUnsentExerciseEdits('u1'), isEmpty);
    expect(await local.getUnsentExerciseEdits('u2'), isEmpty);
  });
}
