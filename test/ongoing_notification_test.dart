import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// The active workout as Android's ongoing notification (#133), checked at the
/// plugin's method channel — the last point before the platform.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;

  setUpAll(() {
    tz.initializeTimeZones();
    // no plugin registrant runs under `flutter test` — see notification_refusal_test
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });
    await initNotifications(platform: TargetPlatform.android);
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  final started = DateTime.now().subtract(const Duration(minutes: 20));

  OngoingWorkout workout({OngoingRest? rest, String channel = 'Workout in progress'}) {
    return (
      workoutId: 'w1',
      startedAt: started,
      title: 'Push day',
      exercise: 'Bench Press (Barbell)',
      next: 'Next: set 2 · 60 kg x 5',
      rest: rest,
      preset: Preset.forge,
      channel: channel,
    );
  }

  Map shown() => calls.lastWhere((call) => call.method == 'show').arguments as Map;
  Map details() => shown()['platformSpecifics'] as Map;

  test('counts up from the start, ongoing and silent, on its own channel', () async {
    await showOngoingWorkoutNotification(workout());

    final created = calls.firstWhere((call) => call.method == 'createNotificationChannel').arguments as Map;
    expect(created['id'], 'Ongoing Workout');
    expect(created['name'], 'Workout in progress');
    expect(created['importance'], Importance.low.value, reason: 'no heads-up or sound on every ticked set');

    expect(shown()['title'], 'Bench Press (Barbell)');
    expect(shown()['body'], 'Next: set 2 · 60 kg x 5');
    expect(shown()['payload'], 'w1');
    expect(details()['channelId'], 'Ongoing Workout');
    expect(details()['ongoing'], isTrue);
    expect(details()['autoCancel'], isFalse);
    expect(details()['onlyAlertOnce'], isTrue);
    expect(details()['usesChronometer'], isTrue);
    expect(details()['chronometerCountDown'], isFalse);
    expect(details()['when'], started.millisecondsSinceEpoch);
    expect(details()['subText'], 'Push day');
  });

  test('while resting the one chronometer counts down to the rest end instead', () async {
    final now = DateTime.now();
    final end = now.add(const Duration(seconds: 60));
    await showOngoingWorkoutNotification(
      workout(rest: (start: now, end: end, label: 'Rest', over: 'Rest complete!')),
    );

    expect(details()['chronometerCountDown'], isTrue);
    expect(details()['when'], end.millisecondsSinceEpoch);
    expect(shown()['body'], 'Rest · Next: set 2 · 60 kg x 5');
  });

  test('a rest already over is shown as the elapsed clock', () async {
    final now = DateTime.now();
    await showOngoingWorkoutNotification(
      workout(
        rest: (
          start: now.subtract(const Duration(seconds: 90)),
          end: now.subtract(const Duration(seconds: 1)),
          label: 'Rest',
          over: 'Rest complete!',
        ),
      ),
    );

    expect(details()['chronometerCountDown'], isFalse);
    expect(details()['when'], started.millisecondsSinceEpoch);
  });

  test('the channel is created once, and again only to rename it', () async {
    // names no other test uses: the last one created is remembered per process
    await showOngoingWorkoutNotification(workout(channel: 'Entrenamiento en curso'));
    await showOngoingWorkoutNotification(workout(channel: 'Entrenamiento en curso'));
    await showOngoingWorkoutNotification(workout(channel: 'Séance en cours'));

    final created = calls
        .where((call) => call.method == 'createNotificationChannel')
        .map((call) => (call.arguments as Map)['name']);
    expect(created, ['Entrenamiento en curso', 'Séance en cours']);
  });

  test('ending cancels only its own notification', () async {
    await cancelOngoingWorkoutNotification();

    expect(calls.single.method, 'cancel');
    expect((calls.single.arguments as Map)['id'], 2);
  });
}
