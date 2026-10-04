import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/keep_awake.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  late Preferences preferences;
  late Workouts workouts;
  late MockWorkoutService local;
  late MockRemoteWorkoutService remote;
  late List<bool> calls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    local = MockWorkoutService();
    remote = MockRemoteWorkoutService();
    workouts = Workouts(service: local, remoteService: remote)..userId = 'u1';
    calls = [];
  });

  tearDown(() {
    workouts.dispose();
    preferences.dispose();
  });

  Future<void> pump(WidgetTester tester, {Future<void> Function({required bool enable})? toggle}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Workouts>.value(value: workouts),
        ],
        child: MaterialApp(
          builder: (context, child) => KeepAwakePresenter(
            toggle:
                toggle ??
                ({required bool enable}) async {
                  calls.add(enable);
                },
            child: child!,
          ),
          home: const Text('Any route'),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }

  for (final on in [false, true]) {
    for (final active in [false, true]) {
      for (final state in AppLifecycleState.values) {
        testWidgets('feature=$on active=$active lifecycle=${state.name}', (tester) async {
          await lifecycle(tester, .resumed);
          await pump(tester);
          await lifecycle(tester, state);
          addTearDown(() => tester.binding.handleAppLifecycleStateChanged(.resumed));
          preferences.setFeature(.keepAwake, on: on);
          if (active) await workouts.startWorkout(source: .blank);
          await tester.pump();
          final visible = state == .resumed || state == .inactive;
          expect(calls.where((enable) => enable).isNotEmpty, on && active && visible);
          expect(find.text('Any route'), findsOneWidget);
          await lifecycle(tester, .resumed);
        });
      }
    }
  }

  testWidgets('switch is live both ways and unrelated workout changes are silent', (tester) async {
    await lifecycle(tester, .resumed);
    await workouts.startWorkout(source: .blank);
    await pump(tester);
    expect(preferences.featureAnswer(.keepAwake), FeatureAnswer.unasked);
    // The first call always goes out, releasing whatever a previous isolate held.
    expect(calls, [false]);

    preferences.setFeature(.keepAwake, on: true);
    await tester.pump();
    workouts.pointedAtExercise = null;
    await tester.pump();
    expect(calls, [false, true]);

    preferences.setFeature(.keepAwake, on: false);
    await tester.pump();
    preferences.setFeature(.keepAwake, on: true);
    await tester.pump();
    expect(calls, [false, true, false, true]);
  });

  testWidgets('background releases, resume reasserts, including a repeated resume', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    await pump(tester);
    await lifecycle(tester, .inactive);
    expect(calls, [true]);
    await lifecycle(tester, .hidden);
    await lifecycle(tester, .paused);
    await lifecycle(tester, .resumed);
    // An OS loss of the lock must not be hidden by the presenter's cache.
    await lifecycle(tester, .resumed);
    expect(calls, [true, false, true, true]);
  });

  testWidgets('a workout loaded after launch acquires the lock', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => Workout());
    await pump(tester);
    expect(calls, [false]);
    await workouts.init();
    await tester.pump();
    expect(calls, [false, true]);
  });

  for (final finish in [false, true]) {
    testWidgets('${finish ? 'finishing (also from watch)' : 'discarding'} releases the lock', (tester) async {
      await lifecycle(tester, .resumed);
      preferences.setFeature(.keepAwake, on: true);
      await workouts.startWorkout(source: .blank);
      await pump(tester);
      if (finish) {
        await workouts.finishActiveWorkout();
      } else {
        await workouts.cancelActiveWorkout();
      }
      await tester.pump();
      expect(calls, [true, false]);
    });
  }

  testWidgets('switching off during an in-flight enable ends with the lock released', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    final enabling = Completer<void>();
    await pump(
      tester,
      toggle: ({required bool enable}) async {
        calls.add(enable);
        if (enable) await enabling.future;
      },
    );
    preferences.setFeature(.keepAwake, on: false);
    await tester.pump();
    expect(calls, [true]);
    enabling.complete();
    await tester.pump();
    expect(calls, [true, false]);
  });

  testWidgets('removing presenter releases and removes listeners', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    await pump(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    preferences.setFeature(.keepAwake, on: false);
    await workouts.cancelActiveWorkout();
    await tester.pump();
    expect(calls, [true, false]);
  });

  testWidgets('an unfocused split-screen window keeps the lock', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    await pump(tester);
    await lifecycle(tester, .inactive);
    await lifecycle(tester, .resumed);
    expect(calls, [true, true]);
  });

  testWidgets('a lock a previous isolate left on is released at start', (tester) async {
    await lifecycle(tester, .resumed);
    await pump(tester);
    expect(calls, [false]);
  });

  testWidgets('finishing releases before the server answers', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    await pump(tester);
    final saving = Completer<Workout>();
    when(remote.saveWorkout(any)).thenAnswer((_) => saving.future);
    final finishing = workouts.finishActiveWorkout();
    await tester.pump();
    expect(workouts.hasActiveWorkout, isTrue);
    expect(calls, [true, false]);
    saving.complete(Workout());
    await finishing;
  });

  testWidgets('signing out mid-workout releases once the next session loads', (tester) async {
    await lifecycle(tester, .resumed);
    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    await pump(tester);
    // Workouts.onSignOut is silent, like every notifier's; the next session's
    // init is what tells listeners the workout is gone.
    workouts
      ..onSignOut()
      ..userId = 'u2';
    when(local.getActiveWorkout('u2')).thenAnswer((_) async => null);
    await workouts.init();
    await tester.pump();
    expect(calls, [true, false]);
  });

  testWidgets('what the presenter holds is what KeepAwake shows', (tester) async {
    await lifecycle(tester, .resumed);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Workouts>.value(value: workouts),
        ],
        child: MaterialApp(
          builder: (context, child) => KeepAwakePresenter(
            toggle: ({required bool enable}) async => calls.add(enable),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Text('awake: ${KeepAwake.of(context)}'),
          ),
        ),
      ),
    );
    expect(find.text('awake: false'), findsOneWidget);

    preferences.setFeature(.keepAwake, on: true);
    await workouts.startWorkout(source: .blank);
    await tester.pump();
    expect(find.text('awake: true'), findsOneWidget);

    await lifecycle(tester, .paused);
    // no frames are drawn while paused, so read it rather than look for it
    expect(KeepAwake.of(tester.element(find.byType(Text))), isFalse);
    await lifecycle(tester, .resumed);
    expect(find.text('awake: true'), findsOneWidget);

    preferences.setFeature(.keepAwake, on: false);
    await tester.pump();
    expect(find.text('awake: false'), findsOneWidget);
  });

  testWidgets('outside a presenter nothing is held', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (context) => Text('awake: ${KeepAwake.of(context)}'))),
    );
    expect(find.text('awake: false'), findsOneWidget);
  });
}
