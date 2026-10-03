import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

void main() {
  late Workout workout;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    workout = Workout()..add(Exercise(name: 'Plank', category: .duration, target: .core));
    now = DateTime.utc(2026, 10, 3);
  });

  test('counts wall-clock seconds, not ticks, and only one set runs', () async {
    final clock = SetStopwatch(now: () => now);
    addTearDown(clock.dispose);
    final set = workout.first.first;
    final next = ExerciseSet(set.exercise);
    workout.first.add(next);
    await clock.start(workout, set);
    now = now.add(const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(clock.elapsed, 3723);
    await clock.start(workout, next);
    expect(clock.setId, set.id);
    expect(clock.stop(), 3723);
    expect(clock.isRunning, isFalse);
    expect(set.duration, isNull, reason: 'only the caller writes the completed duration');
  });

  test('a cold start restores the instant, and stop removes the local entry', () async {
    final first = SetStopwatch(persistent: true, now: () => now);
    await first.start(workout, workout.first.first);
    first.dispose();
    now = now.add(const Duration(minutes: 9, seconds: 5));
    final resumed = SetStopwatch(persistent: true, now: () => now);
    addTearDown(resumed.dispose);
    await resumed.restore(workout);
    expect(resumed.setId, workout.first.first.id);
    expect(resumed.elapsed, 545);
    resumed.stop();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('setStopwatch.running'), isNull);
  });

  test('completed, missing, other-workout and malformed entries are discarded', () async {
    final set = workout.first.first;
    for (final entry in [
      'broken',
      jsonEncode({'workoutId': 'elsewhere', 'setId': set.id, 'start': now.toIso8601String()}),
      jsonEncode({'workoutId': workout.id, 'setId': 'gone', 'start': now.toIso8601String()}),
      jsonEncode({'workoutId': workout.id, 'setId': set.id, 'start': 'bad'}),
    ]) {
      SharedPreferences.setMockInitialValues({'setStopwatch.running': entry});
      final clock = SetStopwatch(persistent: true);
      await clock.restore(workout);
      expect(clock.isRunning, isFalse);
      clock.dispose();
    }
    set.isCompleted = true;
    SharedPreferences.setMockInitialValues({
      'setStopwatch.running': jsonEncode({
        'workoutId': workout.id,
        'setId': set.id,
        'start': now.toIso8601String(),
      }),
    });
    final clock = SetStopwatch(persistent: true);
    await clock.restore(workout);
    expect(clock.isRunning, isFalse);
    clock.dispose();
  });

  test('a completed set or a non-timed set never starts', () async {
    final clock = SetStopwatch();
    addTearDown(clock.dispose);
    workout.first.first.isCompleted = true;
    await clock.start(workout, workout.first.first);
    expect(clock.isRunning, isFalse);
    final bench = Exercise(name: 'Bench', category: .barbell, target: .chest);
    workout.add(bench);
    await clock.start(workout, workout.last.first);
    expect(clock.isRunning, isFalse);
  });
}
