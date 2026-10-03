import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// Every way into a new workout asks before it discards the active one, and
/// deletes it before the new one starts (#228).
void main() {
  late MockWorkoutService local;
  late Workouts workouts;

  // discarding clears the old workout's notifications: no plugin runs under
  // `flutter test`, so it needs a stand-in (see workout_detail_utils_test.dart)
  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
    local = MockWorkoutService();
    when(local.startWorkout(any, any)).thenAnswer((_) async {});
    when(local.deleteWorkout(any)).thenAnswer((_) async {});
    workouts = Workouts(service: local, remoteService: MockRemoteWorkoutService())..userId = 'u1';
  });

  /// Pumps a bare screen and asks for a new workout from it, the way every
  /// entry point does.
  Future<void> startPull(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<Workouts>.value(
        value: workouts,
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    unawaited(startWorkoutOverActive(context, () => workouts.startWorkout(source: .blank, name: 'Pull')));
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing active, it just starts', (tester) async {
    await startPull(tester);

    expect(find.byKey(WorkoutDetailKeys.discardAndStart), findsNothing);
    expect(workouts.activeWorkout?.name, 'Pull');
  });

  testWidgets('keeping the active one changes nothing', (tester) async {
    await workouts.startWorkout(source: .blank, name: 'Push');
    final push = workouts.activeWorkout!.id;
    await startPull(tester);

    await tester.tap(find.text('No, keep current workout'));
    await tester.pumpAndSettle();

    expect(workouts.activeWorkout!.id, push);
    verifyNever(local.deleteWorkout(any));
  });

  testWidgets('discarding deletes the active one, then starts the new one', (tester) async {
    await workouts.startWorkout(source: .blank, name: 'Push');
    final push = workouts.activeWorkout!.id;
    await startPull(tester);

    await tester.tap(find.byKey(WorkoutDetailKeys.discardAndStart));
    await tester.pumpAndSettle();

    // the old one goes before the new one is written, never after
    verifyInOrder([
      local.deleteWorkout(push),
      local.startWorkout(argThat(isA<Workout>().having((workout) => workout.name, 'name', 'Pull')), any),
    ]);
    expect(workouts.activeWorkout?.name, 'Pull');
  });
}
