import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/alarms.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  group('Alarms persistence (#141)', () {
    late _Store store;
    late DateTime clock;
    late Alarms alarms;
    final bench = Exercise.fromJson({
      'id': 'id-bench',
      'name': 'Bench Press',
      'category': 'Barbell',
      'target': 'Chest',
      'archived': false,
    });

    setUp(() {
      clock = DateTime.utc(2026, 1, 1);
      store = _Store();
      alarms = Alarms(tick: const Duration(milliseconds: 10), now: () => clock, store: store);
    });

    tearDown(() => alarms.stopActiveExerciseTimer());

    test('a started rest is written, an adjusted one rewritten, a skipped one cleared', () async {
      alarms.startActiveExerciseTimer(90, exerciseId: 'x1');
      expect(store.saved, (exerciseId: 'x1', end: clock.add(const Duration(seconds: 90)), total: 90));

      alarms.adjustActiveExerciseTime(10);
      expect(store.saved, (exerciseId: 'x1', end: clock.add(const Duration(seconds: 100)), total: 100));

      alarms.stopActiveExerciseTimer();
      expect(store.saved, isNull);
    });

    test('a rest that ran out is cleared', () async {
      alarms.startActiveExerciseTimer(1, exerciseId: 'x1');
      clock = clock.add(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(alarms.remainsInActiveExercise, isNull);
      expect(store.saved, isNull);
    });

    test('restore picks up a rest of the active workout with the time it has left', () async {
      final workout = Workout(name: 'Push');
      final exercise = workout.add(bench);
      store.saved = (exerciseId: exercise.id, end: clock.add(const Duration(seconds: 40)), total: 90);

      await alarms.restore(workout);

      expect(alarms.activeExerciseId, exercise.id);
      expect(alarms.remainsInActiveExercise?.value, 40);
      expect(alarms.activeExerciseTotal, 90);
      expect(alarms.activeExerciseEnd, clock.add(const Duration(seconds: 40)));
    });

    test('restore forgets a rest that is over, or of an exercise the workout does not have', () async {
      final workout = Workout(name: 'Push')..add(bench);
      store.saved = (exerciseId: 'elsewhere', end: clock.add(const Duration(seconds: 40)), total: 90);
      await alarms.restore(workout);
      expect(alarms.activeExerciseId, isNull);
      expect(store.saved, isNull);

      final exercise = workout.first;
      store.saved = (exerciseId: exercise.id, end: clock.subtract(const Duration(seconds: 1)), total: 90);
      await alarms.restore(workout);
      expect(alarms.activeExerciseId, isNull);
      expect(store.saved, isNull);

      store.saved = (exerciseId: exercise.id, end: clock.add(const Duration(seconds: 40)), total: 90);
      await alarms.restore(null);
      expect(alarms.activeExerciseId, isNull);
      expect(store.saved, isNull);
    });

    test('restore never replaces a rest already counting', () async {
      final workout = Workout(name: 'Push');
      final exercise = workout.add(bench);
      alarms.startActiveExerciseTimer(30, exerciseId: 'live');
      store.saved = (exerciseId: exercise.id, end: clock.add(const Duration(seconds: 40)), total: 90);

      await alarms.restore(workout);

      expect(alarms.activeExerciseId, 'live');
    });
  });

  group('Alarms (unit)', () {
    late Alarms alarms;
    late int notifications;
    const tick = Duration(milliseconds: 10);
    late DateTime clock;

    /// Advances the countdown by [ticks], on a clock the test owns.
    ///
    /// The real delay is still needed — `Timer.periodic` fires on real time —
    /// but the *remaining* count is recomputed from `end - now` on every tick,
    /// so reading a real clock made the arithmetic depend on how punctual the
    /// delay was. A loaded CI runner overshooting by one tick turned 499 into
    /// 498 with nothing wrong. Moving the clock in exact steps removes that.
    Future<void> elapse(int ticks) async {
      clock = clock.add(tick * ticks);
      // Add a small epsilon to ensure the periodic callback has time to run
      final total = tick * ticks + const Duration(milliseconds: 2);
      await Future.delayed(total);
    }

    setUp(() {
      clock = DateTime.utc(2026, 1, 1);
      alarms = Alarms(tick: tick, now: () => clock);
      notifications = 0;
      alarms.addListener(() => notifications++);
    });

    tearDown(() {
      // Ensure no active timers leak between tests
      alarms.stopActiveExerciseTimer();
    });

    test('startActiveExerciseTimer initializes timer, remains, and notifies once', () async {
      alarms.startActiveExerciseTimer(5, exerciseId: 'bench');

      expect(alarms.activeExerciseTimer, isA<Timer>());
      expect(alarms.remainsInActiveExercise, isA<ValueNotifier<int>>());
      expect(alarms.activeExerciseTotal, 5);
      expect(alarms.remainsInActiveExercise!.value, 5);
      expect(notifications, 1, reason: 'Should notify once upon start');

      // Wait one tick
      await elapse(1);
      expect(alarms.remainsInActiveExercise!.value, 499);
    });

    test('timer decrements once per tick and stops at zero calling onComplete once', () async {
      var completed = 0;
      alarms.startActiveExerciseTimer(2, exerciseId: 'bench', onComplete: () => completed++);

      expect(alarms.remainsInActiveExercise!.value, 2);
      await elapse(1);
      expect(alarms.remainsInActiveExercise!.value, 199);
      expect(completed, 0);

      await elapse(198);
      // At this point remains reached 0 but timer completes on the next tick
      expect(alarms.remainsInActiveExercise, isNotNull);
      expect(alarms.remainsInActiveExercise!.value, lessThanOrEqualTo(1));
      expect(alarms.activeExerciseTimer, isA<Timer>());
      expect(completed, 0);

      // One more tick completes and stops
      await elapse(1);
      expect(alarms.activeExerciseTimer, isNull);
      expect(alarms.remainsInActiveExercise, isNull);
      expect(alarms.activeExerciseTotal, isNull);
      expect(completed, 1);

      // Further time elapse should not call onComplete again
      await elapse(5);
      expect(completed, 1);

      // Expect at least one notify on stop
      expect(notifications >= 2, isTrue, reason: 'start and stop should notify');
    });

    test('stopActiveExerciseTimer cancels timer, disposes remains, clears state, and notifies', () async {
      alarms.startActiveExerciseTimer(10, exerciseId: 'bench');
      final oldRemains = alarms.remainsInActiveExercise!;
      expect(notifications, 1);

      alarms.stopActiveExerciseTimer();
      expect(alarms.activeExerciseTimer, isNull);
      expect(alarms.remainsInActiveExercise, isNull);
      expect(alarms.activeExerciseTotal, isNull);
      expect(notifications, 2);

      // disposed ValueNotifier should throw if used
      expect(() => oldRemains.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('adjustActiveExerciseTime increases and decreases with clamping at 0, and notifies', () async {
      alarms.startActiveExerciseTimer(10, exerciseId: 'bench');
      notifications = 0; // reset to count adjusts

      // Increase by 5
      alarms.adjustActiveExerciseTime(5);
      expect(alarms.remainsInActiveExercise!.value, 15);
      expect(alarms.activeExerciseTotal, 15);
      expect(notifications, 1);

      // Decrease by 20 -> clamp to 0
      alarms.adjustActiveExerciseTime(-20);
      expect(alarms.remainsInActiveExercise!.value, 0);
      expect(alarms.activeExerciseTotal, 0);
      expect(notifications, 2);

      // With zero remains, timer should complete on the next tick
      await elapse(1);
      expect(alarms.activeExerciseTimer, isNull);
      expect(alarms.remainsInActiveExercise, isNull);
    });

    test('activeExerciseEnd is the countdown\'s wall-clock end, moved by adjustments', () async {
      expect(alarms.activeExerciseEnd, isNull);

      alarms.startActiveExerciseTimer(90, exerciseId: 'bench');
      expect(alarms.activeExerciseEnd, clock.add(const Duration(seconds: 90)));

      alarms.adjustActiveExerciseTime(-30);
      expect(alarms.activeExerciseEnd, clock.add(const Duration(seconds: 60)));

      alarms.stopActiveExerciseTimer();
      expect(alarms.activeExerciseEnd, isNull);
    });

    test('starting a new timer cancels previous timer and disposes the old remains', () async {
      alarms.startActiveExerciseTimer(5, exerciseId: 'bench');
      final firstRemains = alarms.remainsInActiveExercise!;

      await elapse(1);
      expect(firstRemains.value, 499);

      alarms.startActiveExerciseTimer(7, exerciseId: 'bench');
      expect(alarms.remainsInActiveExercise, isNot(equals(firstRemains)));
      expect(alarms.activeExerciseTotal, 7);

      // Old remains should be disposed and unusable
      expect(() => firstRemains.addListener(() {}), throwsA(isA<FlutterError>()));

      // New timer runs independently
      await elapse(1);
      expect(alarms.remainsInActiveExercise!.value, 699);
    });

    test('the countdown belongs to one exercise, and the most recent start takes it over', () async {
      alarms.startActiveExerciseTimer(5, exerciseId: 'bench');
      expect(alarms.activeExerciseId, 'bench');

      // another exercise starts resting: it owns the one countdown now
      alarms.startActiveExerciseTimer(7, exerciseId: 'squat');
      expect(alarms.activeExerciseId, 'squat');
      expect(alarms.activeExerciseTotal, 7);

      alarms.stopActiveExerciseTimer();
      expect(alarms.activeExerciseId, isNull);
    });

    test('abandoning the countdown withdraws its notification, running out does not', () async {
      var cancelled = 0;
      final alarms = Alarms(tick: tick, cancelRestTimerNotifications: () => cancelled++);

      // a skip cancels the pending "rest complete" notification
      alarms.startActiveExerciseTimer(5, exerciseId: 'bench');
      alarms.stopActiveExerciseTimer();
      expect(cancelled, 1);

      // natural completion leaves the just-fired notification alone
      alarms.startActiveExerciseTimer(1, exerciseId: 'bench');
      await elapse(101);
      expect(alarms.activeExerciseTimer, isNull, reason: 'timer should have run out');
      expect(cancelled, 1);
    });

    test('onSignOut stops active exercise timer and notifies', () async {
      alarms.startActiveExerciseTimer(3, exerciseId: 'bench');
      notifications = 0;
      alarms.onSignOut();
      expect(alarms.activeExerciseTimer, isNull);
      expect(alarms.remainsInActiveExercise, isNull);
      expect(alarms.activeExerciseTotal, isNull);
      expect(notifications, 1);
    });
  });

  group('Alarms with Provider (widget)', () {
    testWidgets('of(context) returns the same instance as provided', (tester) async {
      late Alarms fromOf;
      final provided = Alarms();

      await tester.pumpWidget(
        ChangeNotifierProvider<Alarms>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              fromOf = Alarms.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(fromOf, provided), isTrue);
    });

    testWidgets('watch(context) rebuilds widget on notifyListeners (start/adjust/stop)', (tester) async {
      final provided = Alarms();
      var builds = 0;

      Widget consumer() {
        return Builder(
          builder: (context) {
            // Read with watch to subscribe
            final remains = Alarms.watch(context).remainsInActiveExercise?.value;
            builds++;
            return Text('remains=${remains ?? -1}', textDirection: TextDirection.ltr);
          },
        );
      }

      await tester.pumpWidget(
        ChangeNotifierProvider<Alarms>.value(
          value: provided,
          child: consumer(),
        ),
      );

      final initialBuilds = builds;
      expect(initialBuilds, 1);

      // Starting should notify and rebuild
      provided.startActiveExerciseTimer(2, exerciseId: 'bench');
      await tester.pump();
      expect(builds, initialBuilds + 1);

      // Adjust should notify and rebuild
      provided.adjustActiveExerciseTime(1);
      await tester.pump();
      expect(builds, initialBuilds + 2);

      // Stopping should notify and rebuild
      provided.stopActiveExerciseTimer();
      await tester.pump();
      expect(builds, initialBuilds + 3);

      // Widget remains present
      expect(find.byType(Text), findsOneWidget);
    });
  });
}

/// The device's memory of a rest, in memory.
class _Store implements RestStore {
  SavedRest? saved;

  @override
  Future<SavedRest?> read() async => saved;

  @override
  Future<void> write(SavedRest rest) async => saved = rest;

  @override
  Future<void> clear() async => saved = null;
}
