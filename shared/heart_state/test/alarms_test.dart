import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/src/alarms.dart';
import 'package:provider/provider.dart';

void main() {
  group('Alarms (unit)', () {
    late Alarms alarms;
    late int notifications;
    const tick = Duration(milliseconds: 10);

    Future<void> elapse(int ticks) async {
      // Add a small epsilon to ensure the periodic callback has time to run
      final total = tick * ticks + const Duration(milliseconds: 2);
      await Future.delayed(total);
    }

    setUp(() {
      alarms = Alarms(tick: tick);
      notifications = 0;
      alarms.addListener(() => notifications++);
    });

    tearDown(() {
      // Ensure no active timers leak between tests
      alarms.stopActiveExerciseTimer();
    });

    test('startActiveExerciseTimer initializes timer, remains, and notifies once', () async {
      alarms.startActiveExerciseTimer(5);

      expect(alarms.activeExerciseTimer, isA<Timer>());
      expect(alarms.remainsInActiveExercise, isA<ValueNotifier<int>>());
      expect(alarms.activeExerciseTotal, 5);
      expect(alarms.remainsInActiveExercise!.value, 5);
      expect(notifications, 1, reason: 'Should notify once upon start');

      // Wait one tick
      await elapse(1);
      expect(alarms.remainsInActiveExercise!.value, 4);
    });

    test('timer decrements once per tick and stops at zero calling onComplete once', () async {
      var completed = 0;
      alarms.startActiveExerciseTimer(2, onComplete: () => completed++);

      expect(alarms.remainsInActiveExercise!.value, 2);
      await elapse(1);
      expect(alarms.remainsInActiveExercise!.value, 1);
      expect(completed, 0);

      await elapse(1);
      // At this point remains reached 0 but timer completes on the next tick
      expect(alarms.remainsInActiveExercise, isNotNull);
      expect(alarms.remainsInActiveExercise!.value, 0);
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
      alarms.startActiveExerciseTimer(10);
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
      alarms.startActiveExerciseTimer(10);
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

    test('starting a new timer cancels previous timer and disposes the old remains', () async {
      alarms.startActiveExerciseTimer(5);
      final firstRemains = alarms.remainsInActiveExercise!;

      await elapse(1);
      expect(firstRemains.value, 4);

      alarms.startActiveExerciseTimer(7);
      expect(alarms.remainsInActiveExercise, isNot(equals(firstRemains)));
      expect(alarms.activeExerciseTotal, 7);

      // Old remains should be disposed and unusable
      expect(() => firstRemains.addListener(() {}), throwsA(isA<FlutterError>()));

      // New timer runs independently
      await elapse(1);
      expect(alarms.remainsInActiveExercise!.value, 6);
    });

    test('onSignOut stops active exercise timer and notifies', () async {
      alarms.startActiveExerciseTimer(3);
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
      provided.startActiveExerciseTimer(2);
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
