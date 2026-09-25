import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// A notification tap that *launched* the app.
///
/// The plugin never hands that tap to `onDidReceiveNotificationResponse`; it
/// only reports it through `getNotificationAppLaunchDetails`. Until that was
/// read, a cold start from any of the app's notifications — the rest timer,
/// the idle reminder, the workout on the lock screen (#133) — opened wherever
/// the app would have opened anyway.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  /// What the platform answers `getNotificationAppLaunchDetails` with.
  Object? launch;
  PlatformException? launchError;

  late List<String> routed;

  setUpAll(() {
    tz.initializeTimeZones();
    // no plugin registrant runs under `flutter test` — see notification_refusal_test
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() {
    launch = null;
    launchError = null;
    routed = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'initialize' => true,
        'getNotificationAppLaunchDetails' when launchError != null => throw launchError!,
        'getNotificationAppLaunchDetails' => launch,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Map<String, Object?> launchedBy(int id, {String? payload}) {
    return {
      'notificationLaunchedApp': true,
      'notificationResponse': {
        'notificationId': id,
        'notificationResponseType': NotificationResponseType.selectedNotification.index,
        'payload': ?payload,
      },
    };
  }

  Future<void> init() {
    return initNotifications(
      platform: TargetPlatform.android,
      onExerciseNotification: (exerciseId) => routed.add('exercise:$exerciseId'),
      onWorkoutTimeoutNotification: () => routed.add('timeout'),
      onOngoingWorkoutNotification: () => routed.add('ongoing'),
      onUnknownNotification: (_) => routed.add('unknown'),
    );
  }

  test('the workout on the lock screen routes like a tap on a running app', () async {
    launch = launchedBy(2, payload: 'w1');
    await init();
    expect(routed, ['ongoing']);
  });

  test('so does the rest timer, with its exercise', () async {
    launch = launchedBy(0, payload: 'bench-press');
    await init();
    expect(routed, ['exercise:bench-press']);
  });

  test('and the idle-workout reminder', () async {
    launch = launchedBy(1);
    await init();
    expect(routed, ['timeout']);
  });

  test('an ordinary launch routes nothing', () async {
    launch = {'notificationLaunchedApp': false};
    await init();
    expect(routed, isEmpty);
  });

  test('launch details the platform cannot give do not fail the start', () async {
    launchError = PlatformException(code: 'unavailable');
    await expectLater(init(), completes);
    expect(routed, isEmpty);
  });
}
