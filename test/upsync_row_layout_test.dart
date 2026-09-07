// Window-size coverage for the upsync row on the profile — the mechanism of
// integration_test/responsive_frame_test.dart applied to a single surface
// (docs/handoff.md #4). The row is a line of prose and a bar, so it measures
// its own LayoutBuilder constraints and caps itself at [readableWidth],
// start-aligned with the chart under it rather than spanning an iPad.
import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);

    // an account owed a replay of one workout the server never answers for,
    // so the row stays in its running state — the one with the bar
    final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    final workout = Workout(name: 'Monday');
    workout.add(bench).add(ExerciseSet(bench, weight: 60, reps: 5)..isCompleted = true);
    workout.finish(DateTime.timestamp());
    when(db.isUpsyncOwed(any)).thenAnswer((_) async => true);
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [workout]);
    when(api.replayWorkout(any)).thenAnswer((_) => Completer<({Workout row, bool created})>().future);
  });

  Future<void> pumpRunningRowAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      // the dashboard animates indefinitely — settle would hang on it
      settle: false,
    );
    await tester.pumpTimes();
    // start-up would start this once the API has its token; `_initApp` runs
    // in Zone.root, which a widget test's fake-async zone never yields to
    unawaited(Upsync.of(tester.element(find.byType(MaterialApp))).run('u1'));
    await tester.pumpTimes();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  }

  testWidgets('an iPad window caps the row at readableWidth, start-aligned', (tester) async {
    await pumpRunningRowAt(tester, const Size(1194, 834));

    final row = find.byKey(AppKeys.upsyncRow);
    expect(tester.getSize(row).width, readableWidth);
    // the chart grid's own inset from the pane's edge — the pane, not the
    // window: on an iPad the navigation rail sits to the left of it
    final pane = tester.getTopLeft(find.byType(CustomScrollView).first).dx;
    expect(tester.getTopLeft(row).dx, pane + 16);
  });

  testWidgets('a phone window gives the row the pane minus the insets', (tester) async {
    await pumpRunningRowAt(tester, const Size(390, 844));

    expect(tester.getSize(find.byKey(AppKeys.upsyncRow)).width, 390 - 32);
  });
}
