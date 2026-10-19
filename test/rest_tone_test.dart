import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart_state/heart_state.dart' show SharedPreferences, silentNotification;
import 'package:timezone/data/latest_all.dart' as tz;

/// The "rest complete" notification's sound under workout sounds (#169), as
/// it reaches Android: off, exactly 1.9's channel and sound; on, a channel per
/// sound playing the bundled file, silent while the app is on screen and plays
/// the sound itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> scheduled;

  setUpAll(() {
    tz.initializeTimeZones();
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduled = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'initialize' => true,
        'zonedSchedule' => scheduled.add(call),
        // the rest is still to come: it may be posted again
        'pendingNotificationRequests' => [
          {'id': 0, 'title': 'Rest complete!', 'body': null, 'payload': 'bench'},
        ],
        _ => null,
      };
    });
    await initNotifications(platform: TargetPlatform.android);
  });

  tearDown(() async {
    await quietRestNotification(quiet: false);
    await publishRestTone(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  final soon = DateTime.now().add(const Duration(minutes: 2));

  Map<Object?, Object?> details(MethodCall call) {
    final arguments = call.arguments as Map;
    return (arguments['platformSpecifics'] ?? arguments['notificationDetails']) as Map<Object?, Object?>;
  }

  test('off, the notification is the one 1.9 posted', () async {
    await scheduleExerciseNotification('bench', soon, title: 'Rest complete!');
    final android = details(scheduled.single);
    expect(android['channelId'], 'Rest Timers');
    expect(android['playSound'], isTrue);
    expect(android['sound'], isNull);
    expect(android['silent'], isFalse);
  });

  test('on, a channel of its own plays the chosen sound', () async {
    await publishRestTone((sound: 'rest_bell', channel: 'Rest timers: Bell'));
    await scheduleExerciseNotification('bench', soon, title: 'Rest complete!');
    final android = details(scheduled.single);
    expect(android['channelId'], 'Rest Timers rest_bell');
    expect(android['channelName'], 'Rest timers: Bell');
    expect(android['sound'], 'rest_bell');
    expect(android['playSound'], isTrue);
  });

  test('at volume off, it plays nothing', () async {
    await publishRestTone((sound: silentNotification, channel: 'Rest timers: silent'));
    await scheduleExerciseNotification('bench', soon, title: 'Rest complete!');
    final android = details(scheduled.single);
    expect(android['channelId'], 'Rest Timers silent');
    expect(android['playSound'], isFalse);
  });

  test('with the app on screen, a pending rest goes up again silent, and back when it leaves', () async {
    await publishRestTone((sound: 'rest_bell', channel: 'Rest timers: Bell'));
    await scheduleExerciseNotification('bench', soon, title: 'Rest complete!', subtitle: 'Squat is next');

    await quietRestNotification(quiet: true);
    await quietRestNotification(quiet: false);

    expect(scheduled.map((call) => details(call)['silent']), [false, true, false]);
    expect((scheduled.last.arguments as Map)['payload'], 'bench', reason: 'the same rest, posted again');
  });

  test('off, on screen changes nothing: 1.9 had the system sound in front too', () async {
    await scheduleExerciseNotification('bench', soon, title: 'Rest complete!');
    await quietRestNotification(quiet: true);
    expect(scheduled, hasLength(1));
  });
}
