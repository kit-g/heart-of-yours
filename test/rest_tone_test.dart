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
  late List<MethodCall> channels;
  late List<Object?> deleted;

  setUpAll(() {
    tz.initializeTimeZones();
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduled = [];
    channels = [];
    deleted = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'initialize' => true,
        'zonedSchedule' => scheduled.add(call),
        'createNotificationChannel' => channels.add(call),
        // the system's own list: what was created and not yet deleted
        'getNotificationChannels' => [
          for (final call in channels)
            if (call.arguments case {'id': final id, 'name': final name} when !deleted.contains(id))
              {
                'id': id,
                'name': name,
                'importance': 3,
                'showBadge': true,
                'bypassDnd': false,
                'playSound': true,
                'enableLights': false,
                'enableVibration': true,
                'ledColor': 0,
              },
        ],
        'deleteNotificationChannel' => deleted.add(call.arguments),
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
    // no rest carries over: the next test's tone would post it again
    await cancelExerciseNotification();
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

  test('a sound chosen mid-rest is that rest\'s, and switched off it is the system\'s again', () async {
    await publishRestTone((sound: 'rest_bell', channel: 'Rest timers: Bell'));
    await scheduleExerciseNotification('bench', soon, title: 'Rest complete!');

    await publishRestTone((sound: 'rest_chime', channel: 'Rest timers: Chime'));
    await publishRestTone(null);

    expect(scheduled.map((call) => details(call)['channelId']), [
      'Rest Timers rest_bell',
      'Rest Timers rest_chime',
      'Rest Timers',
    ]);
  });

  test('a rest picked up after the process died is posted again from what was kept', () async {
    await publishRestTone((sound: 'rest_bell', channel: 'Rest timers: Bell'));

    await quietRestNotification(
      quiet: true,
      savedRest: () async => (exerciseId: 'bench', end: soon, total: 120),
    );

    final android = details(scheduled.single);
    expect(android['silent'], isTrue);
    expect((scheduled.single.arguments as Map)['title'], 'Rest complete!');
  });

  test('each sound\'s channel is the default one with another sound, and is renamed with the language', () async {
    await publishRestTone((sound: 'rest_bell', channel: 'Rest timers: Bell'));
    await publishRestTone((sound: 'rest_bell', channel: 'Таймеры отдыха: колокол'));

    // after the default channel, made as the plugin starts
    final made = channels.map((call) => call.arguments as Map).skip(1).toList();
    expect(made.map((each) => (each['id'], each['name'])), [
      ('Rest Timers rest_bell', 'Rest timers: Bell'),
      ('Rest Timers rest_bell', 'Таймеры отдыха: колокол'),
    ]);
    expect(made.first['sound'], 'rest_bell');
    expect(made.first['enableVibration'], isTrue, reason: 'as the default channel, which buzzes');
  });

  test('a sound no longer used leaves no channel behind, and off leaves none at all', () async {
    await publishRestTone((sound: 'rest_bell', channel: 'Rest timers: Bell'));
    await publishRestTone((sound: 'rest_chime', channel: 'Rest timers: Chime'));
    expect(deleted, ['Rest Timers rest_bell']);

    await publishRestTone(null);
    expect(deleted, ['Rest Timers rest_bell', 'Rest Timers rest_chime']);
  });
}
