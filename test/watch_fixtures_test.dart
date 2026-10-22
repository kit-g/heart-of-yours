import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/tokens.dart';

/// The watch payloads as the phone sends them, kept as JSON in
/// `test/fixtures/watch/` for both watches' tests to read (#466): the Apple
/// Watch's (ios/WatchTests) and Wear OS's (android/wear/src/test). A change to
/// what the phone sends that one watch cannot read fails there, not on a wrist.
///
/// Run with `UPDATE_WATCH_FIXTURES=1` to write them after a deliberate change,
/// then make both watches read the new shape.
void main() {
  final update = Platform.environment['UPDATE_WATCH_FIXTURES'] == '1';
  const dir = 'test/fixtures/watch';

  void matches(String name, Object? payload) {
    final file = File('$dir/$name.json');
    final encoded = '${const JsonEncoder.withIndent('  ').convert(payload)}\n';
    if (update) file.writeAsStringSync(encoded);
    expect(
      file.readAsStringSync(),
      encoded,
      reason: '$name.json is what the phone sends; rerun with UPDATE_WATCH_FIXTURES=1',
    );
  }

  final start = DateTime.utc(2026, 10, 22, 18);
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  const controls = (
    done: 'Done',
    skip: 'Skip',
    add: '+10s',
    subtract: '-10s',
    reps: 'Reps',
    unreachable: "Syncs with your phone when it's back",
    heartRate: 'Heart rate',
    bpm: 'bpm',
    energy: 'Active energy',
    kcal: 'kcal',
    finish: 'Finish',
    finishTitle: 'Complete your workout?',
    finishConfirm: "Yes, I'm done!",
    finishCancel: 'No, one more set!',
    save: 'Save',
    notDone: 'Not done',
    restLabel: 'Rest',
    restOver: 'Rest complete!',
    allDone: 'All done',
    idle: 'Start a workout on your phone',
    sending: 'Sending to your phone…',
    finishedAway: "Saved on your watch. Your phone gets it when it's back.",
    pause: 'Pause',
    resume: 'Resume',
    paused: 'Paused',
  );

  final exercises = <WatchExercise>[
    (
      id: 'bench',
      name: 'Bench Press (Barbell)',
      unit: 'kg',
      step: 2.5,
      weighted: true,
      counted: true,
      rest: 90,
      sets: [
        (
          id: 'b1',
          mark: 'W',
          type: 'Warm-up',
          weight: 40,
          reps: 10,
          done: true,
          position: 'Warm-up',
          previous: null,
          next: 'Next: 60 kg × 5',
        ),
        (
          id: 'b2',
          mark: '1',
          type: null,
          weight: 60,
          reps: 5,
          done: true,
          position: 'Set 1 of 2',
          previous: 'Last time: 57.5 kg × 5',
          next: 'Next: 62.5 kg × 5',
        ),
        (
          id: 'b3',
          mark: '2',
          type: null,
          weight: 62.5,
          reps: 5,
          done: false,
          position: 'Set 2 of 2',
          previous: 'Last time: 60 kg × 5',
          next: 'Next: Pull-up',
        ),
      ],
    ),
    (
      id: 'pullup',
      name: 'Pull-up',
      unit: null,
      step: 2.5,
      weighted: false,
      counted: true,
      rest: null,
      sets: [
        (
          id: 'p1',
          mark: '1',
          type: null,
          weight: null,
          reps: 8,
          done: false,
          position: 'Set 1 of 1',
          previous: 'Last time: 7 Reps',
          next: 'All done',
        ),
      ],
    ),
  ];

  OngoingWorkout workout({
    OngoingRest? rest,
    DateTime? pausedAt,
    String exercise = 'Bench Press (Barbell)',
    String next = 'Next: 62.5 kg × 5',
  }) => (
    workoutId: 'w1',
    startedAt: start,
    clockStart: at(30),
    pausedAt: pausedAt,
    pausedLabel: 'Paused',
    title: 'Push day',
    exercise: exercise,
    next: next,
    rest: rest,
    done: null,
    stopwatch: null,
    preset: Preset.forge,
    channel: 'workout',
  );

  test('a workout resting, with the set up next', () {
    final state = WatchWorkout(
      workout(
        rest: (
          start: at(600),
          end: at(690),
          label: 'Rest',
          over: 'Rest complete!',
          minus: '-10s',
          plus: '+10s',
          skip: 'Skip',
        ),
      ),
      set: (
        exerciseId: 'bench',
        setId: 'b3',
        weight: 62.5,
        reps: 5,
        unit: 'kg',
        step: 2.5,
        previous: 'Last time: 60 kg × 5',
        position: 'Set 2 of 2',
      ),
      controls: controls,
      activity: 'strength',
      exercises: exercises,
      pausable: true,
      pauses: [(start: at(5), end: at(35))],
    );
    matches('workout_resting', state.toMap());
  });

  test('a workout paused, every set ticked', () {
    final state = WatchWorkout(
      workout(pausedAt: at(900), exercise: 'Pull-up', next: 'All done'),
      controls: controls,
      activity: 'strength',
      exercises: exercises,
      pausable: true,
    );
    matches('workout_paused_done', state.toMap());
  });

  test('no workout, and switched off', () {
    matches('idle', const WatchMessage.idle('Start a workout on your phone').toMap());
    matches('off', const WatchMessage.off('Turned off in Heart on your phone').toMap());
  });

  test('every command a watch sends reads as the one it means', () {
    final file = File('$dir/commands.json');
    final commands = (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, Object?>>();
    expect(commands.map((each) => WatchCommand.fromMap(each).runtimeType), [
      WatchComplete,
      WatchComplete,
      WatchEditSet,
      WatchUntickSet,
      WatchSkipRest,
      WatchAdjustRest,
      WatchFinishWorkout,
      WatchPauseWorkout,
      WatchResumeWorkout,
    ]);
    final tick = WatchCommand.fromMap(commands.first) as WatchComplete;
    expect(
      (tick.setId, tick.weight, tick.reps, tick.at),
      ('b3', 62.5, 5, DateTime.fromMillisecondsSinceEpoch(1792692000000)),
    );
    expect(
      (WatchCommand.fromMap(commands[1]) as WatchComplete).weight,
      isNull,
      reason: 'a reps-only set sends no weight',
    );
  });
}
