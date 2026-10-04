import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart_state/heart_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:heart_models/heart_models.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../test/mocks.mocks.dart';
import '../test/support/harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native wake lock follows the Features switch and workout', (tester) async {
    // Live test binding resets lifecycle to null after a hot restart. This
    // native check runs in the foreground; unit tests drive all other states.
    if (binding.lifecycleState == null) binding.handleAppLifecycleStateChanged(.resumed);
    // Keep this test independent of the simulator's health permissions/data.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_health'),
      (call) async => switch (call.method) {
        'getHealthConnectSdkStatus' => 1,
        'hasPermissions' => false,
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_health'),
        null,
      ),
    );
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    when(api.saveWorkout(any)).thenAnswer((call) async => call.positionalArguments.first as Workout);
    final router = HeartRouter();
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      router: router,
      firebaseAuth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1'), signedIn: true),
      settle: false,
    );
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    final workouts = Workouts.of(context);
    final preferences = Preferences.of(context);

    Future<void> startWorkout() async {
      await tester.runAsync(() {
        final started = workouts.startWorkout(source: .blank);
        // The workout has already been shown; keep this test on Features.
        workouts.notifyOfActiveWorkout();
        return started;
      });
    }

    Future<void> expectLock({required bool enabled}) async {
      await tester.pumpTimes();
      await tester.runAsync(() async {
        // Platform calls are queued independently of Flutter's test clock.
        for (final _ in Iterable.generate(50)) {
          if (await WakelockPlus.enabled == enabled) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(
          await WakelockPlus.enabled,
          enabled,
          reason:
              'lifecycle=${binding.lifecycleState}, feature=${preferences.isOn(.keepAwake)}, active=${workouts.hasActiveWorkout}',
        );
      });
    }

    var convertedSurface = false;
    Future<void> screenshot(String state) async {
      if (Theme.of(context).platform == TargetPlatform.android && !convertedSurface) {
        await binding.convertFlutterSurfaceToImage();
        convertedSurface = true;
        await tester.pump();
      }
      final platform = Theme.of(context).platform.name;
      final width = View.of(context).physicalSize.width.toInt();
      await binding.takeScreenshot('keep-awake-$platform-$width-$state');
    }

    router.config.go('/profile/settings/features');
    await tester.pumpTimes();
    final row = find.byKey(const ValueKey('feature-keepAwake'));
    await tester.ensureVisible(row);
    await tester.pumpTimes();
    expect(preferences.isOn(.keepAwake), isFalse);
    await expectLock(enabled: false);
    await screenshot('off');

    await tester.tap(row);
    await expectLock(enabled: false); // No active workout yet.
    expect(preferences.isOn(.keepAwake), isTrue);
    await startWorkout();
    await expectLock(enabled: true);
    await screenshot('on');

    // The feature holds on the Features page, and switching off is immediate.
    await tester.tap(row);
    await expectLock(enabled: false);
    await tester.tap(row);
    await expectLock(enabled: true);

    await tester.runAsync(() => workouts.finishActiveWorkout());
    await expectLock(enabled: false);
    await startWorkout();
    await expectLock(enabled: true);
    await tester.runAsync(workouts.cancelActiveWorkout);
    await expectLock(enabled: false);
  });
}
