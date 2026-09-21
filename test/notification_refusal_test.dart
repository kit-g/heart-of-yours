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
/// The refusal is swallowed. Everything else is not: a missing drawable is a
/// bug we shipped twice (F17, F20) and it has to stay loud.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  late List<String> called;
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
    scheduleError = null;
    installHandler();
    await initNotifications(platform: TargetPlatform.android);
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
    });

    test('the idle-workout notification gives up quietly', () async {
      respondWith(refusal);

      await expectLater(
        scheduleWorkoutTimeoutNotification(soon, title: 'Still training?'),
        completes,
      );
      expect(called, contains('zonedSchedule'));
    });
  });

  group('anything else', () {
    test('a missing drawable still throws, because that one is ours', () async {
      // The exact shape of F17: the release build's resource shrinker dropped
      // `ic_stat_heart`, notifications died in every store build, and Sentry was
      // the only thing that noticed. Swallowing this class would have hidden it.
      respondWith(
        PlatformException(
          code: 'invalid_icon',
          message: 'The resource ic_stat_heart could not be found.',
        ),
      );

      await expectLater(
        scheduleExerciseNotification('bench-press', soon, title: 'Rest complete!'),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'invalid_icon'),
        ),
      );
    });

    test('an unauthorized-looking code from another domain is not special-cased away', () async {
      respondWith(PlatformException(code: 'channel_not_found', message: 'no channel'));

      await expectLater(
        scheduleWorkoutTimeoutNotification(soon, title: 'Still training?'),
        throwsA(isA<PlatformException>()),
      );
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
