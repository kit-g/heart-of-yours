import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Scheduling a notification the user has refused permission for.
///
/// iOS answers a schedule with `PlatformException(Error 2003, Repository could
/// not save notification. Source is not authorized., UNErrorDomain)` when
/// permission was never granted or has since been revoked. Nothing in the app
/// awaits these calls, so that throw escaped to `PlatformDispatcher.onError`
/// and was recorded as a fatal — on the screen that ends a workout, for the
/// ordinary act of declining a prompt (HEART-OF-YOURS-1W).
///
/// The refusal is swallowed silently. Everything else — `invalid_icon` being the
/// live example — is reported and then swallowed too: nothing awaits these
/// calls, so rethrowing made it an unhandled error on the zone, recorded fatal
/// on the workout-finished screen and, through `initialize`, on app start. The
/// report is what keeps the signal that silencing it would lose.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  late List<String> called;
  late List<Object> reported;
  PlatformException? scheduleError;

  /// Every plugin call succeeds except `zonedSchedule`, which throws whatever
  /// [scheduleError] currently holds.
  ///
  /// The plugin has to be initialised before it will schedule anything, and
  /// initialising is itself a channel call — so a handler that threw at
  /// everything never reached the code under test.
  void installHandler() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      called.add(call.method);
      if (call.method == 'zonedSchedule' && scheduleError != null) throw scheduleError!;
      // `initialize` is typed to return a bool; everything used here is void.
      return call.method == 'initialize' ? true : null;
    });
  }

  void respondWith(PlatformException error) => scheduleError = error;

  setUpAll(() {
    tz.initializeTimeZones();
    // `flutter test` runs no plugin registrant, so the platform interface's
    // instance is never set and every `resolvePlatformSpecificImplementation`
    // throws a LateInitializationError. Registering the Android implementation
    // by hand is what a registrant would have done; the method channel below
    // stands in for the native side.
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    called = <String>[];
    reported = <Object>[];
    scheduleError = null;
    installHandler();
    await initNotifications(
      platform: TargetPlatform.android,
      onError: (error, {stacktrace}) => reported.add(error),
    );
    called.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  final soon = DateTime.now().add(const Duration(minutes: 2));

  group('the user declined notifications', () {
    final refusal = PlatformException(
      code: 'Error 2003',
      message: 'Repository could not save notification. Source is not authorized.',
      details: 'UNErrorDomain',
    );

    test('a rest-timer notification gives up quietly', () async {
      respondWith(refusal);

      await expectLater(
        scheduleExerciseNotification('bench-press', soon, title: 'Rest complete!'),
        completes,
      );
      expect(called, contains('zonedSchedule'), reason: 'the schedule has to be attempted, not skipped');
      expect(reported, isEmpty, reason: 'declining is an answer, not a fault');
    });

    test('the idle-workout notification gives up quietly', () async {
      respondWith(refusal);

      await expectLater(
        scheduleWorkoutTimeoutNotification(soon, title: 'Still training?'),
        completes,
      );
      expect(called, contains('zonedSchedule'));
      expect(reported, isEmpty);
    });
  });

  group('anything else', () {
    test('a missing drawable is reported, not thrown', () async {
      // The exact shape of F17: the release build's resource shrinker dropped
      // `ic_stat_heart`, notifications died in every store build, and Sentry was
      // the only thing that noticed. Swallowing this class would have hidden it.
      respondWith(
        PlatformException(
          code: 'invalid_icon',
          message: 'The resource ic_stat_heart could not be found.',
        ),
      );

      // Not thrown: the app cannot repair a resource table it did not break,
      // and a notification that will not schedule is not worth a crash on the
      // screen that ends a workout.
      await expectLater(
        scheduleExerciseNotification('bench-press', soon, title: 'Rest complete!'),
        completes,
      );
      expect(
        reported,
        [isA<PlatformException>().having((e) => e.code, 'code', 'invalid_icon')],
        reason: 'silencing it would lose the only signal we get from these devices',
      );
    });

    test('an unrelated failure is reported too, not quietly dropped', () async {
      respondWith(PlatformException(code: 'channel_not_found', message: 'no channel'));

      await expectLater(
        scheduleWorkoutTimeoutNotification(soon, title: 'Still training?'),
        completes,
      );
      expect(reported, [isA<PlatformException>().having((e) => e.code, 'code', 'channel_not_found')]);
    });
  });

  test('a time already past is not scheduled at all', () async {
    respondWith(PlatformException(code: 'should_not_be_called'));

    await scheduleExerciseNotification(
      'bench-press',
      DateTime.now().subtract(const Duration(minutes: 1)),
      title: 'Rest complete!',
    );

    expect(called, isEmpty);
  });
}
