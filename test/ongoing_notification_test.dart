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

  /// What Android reports as showing. The notification is up unless a test
  /// says the user swiped it away.
  late List<Map<String, Object?>> active;
  PlatformException? activeError;

  setUpAll(() {
    tz.initializeTimeZones();
    // no plugin registrant runs under `flutter test` — see notification_refusal_test
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    calls = [];
    active = [
      {'id': 2},
    ];
    activeError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'getActiveNotifications' when activeError != null => throw activeError!,
        'getActiveNotifications' => active,
        _ => null,
      };
    });
    await initNotifications(platform: TargetPlatform.android);
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  final started = DateTime.now().subtract(const Duration(minutes: 20));

  OngoingWorkout workout({String id = 'w1', OngoingRest? rest, String channel = 'Workout in progress'}) {
    return (
      workoutId: id,
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
    expect(details()['ongoing'], isFalse, reason: 'the user can swipe it away (#133)');
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

  group('a swipe', () {
    int shows() => calls.where((call) => call.method == 'show').length;

    test('keeps it away for the rest of that workout', () async {
      await showOngoingWorkoutNotification(workout(id: 'swiped'));
      expect(shows(), 1);

      active = [];
      await showOngoingWorkoutNotification(workout(id: 'swiped'));
      expect(shows(), 1, reason: 'posted for this workout and gone: the user dismissed it');

      active = [
        {'id': 2},
      ];
      await showOngoingWorkoutNotification(workout(id: 'swiped'));
      expect(shows(), 1, reason: 'a dismissal holds even once something else is showing again');

      await showOngoingWorkoutNotification(workout(id: 'the next one'));
      expect(shows(), 2, reason: 'the next workout gets it back');
    });

    test('is never inferred from a question the platform cannot answer', () async {
      await showOngoingWorkoutNotification(workout(id: 'unanswered'));
      activeError = PlatformException(code: 'unavailable');
      await showOngoingWorkoutNotification(workout(id: 'unanswered'));

      expect(shows(), 2);
    });
  });

  test('ending cancels only its own notification', () async {
    await cancelOngoingWorkoutNotification();

    expect(calls.single.method, 'cancel');
    expect((calls.single.arguments as Map)['id'], 2);
  });
}
