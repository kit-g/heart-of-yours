import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart_state/heart_state.dart';
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

  /// What the platform holds scheduled: the "rest complete" notification,
  /// unless a test says there is none.
  late List<Map<String, Object?>> pending;

  setUpAll(() {
    tz.initializeTimeZones();
    // no plugin registrant runs under `flutter test` — see notification_refusal_test
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    // the buttons' queue for a launch to come (#141) lives in preferences
    SharedPreferences.setMockInitialValues({});
    calls = [];
    active = [
      {'id': 2},
    ];
    activeError = null;
    pending = [
      {'id': 0, 'title': 'Rest complete!', 'body': '60 kg x 5', 'payload': 'id-bench'},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'getActiveNotifications' when activeError != null => throw activeError!,
        'getActiveNotifications' => active,
        'pendingNotificationRequests' => pending,
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

  OngoingWorkout workout({
    String id = 'w1',
    OngoingRest? rest,
    OngoingDone? done,
    ({DateTime start, DateTime? pausedAt, String label})? stopwatch,
    String channel = 'Workout in progress',
    DateTime? clockStart,
    DateTime? pausedAt,
  }) {
    return (
      workoutId: id,
      startedAt: started,
      clockStart: clockStart ?? started,
      pausedAt: pausedAt,
      pausedLabel: 'Paused',
      title: 'Push day',
      exercise: 'Bench Press (Barbell)',
      next: 'Next: set 2 · 60 kg x 5',
      rest: rest,
      done: done,
      preset: Preset.forge,
      stopwatch: stopwatch,
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
    // the payload is what the rest buttons' background isolate (#141) has
    // to repost from: the whole display, not the id alone
    expect(jsonDecode(shown()['payload'] as String), containsPair('workoutId', 'w1'));
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
      workout(
        rest: (start: now, end: end, label: 'Rest', over: 'Rest complete!', minus: '-10s', plus: '+10s', skip: 'Skip'),
      ),
    );

    expect(details()['chronometerCountDown'], isTrue);
    expect(details()['when'], end.millisecondsSinceEpoch);
    expect(shown()['body'], 'Rest · Next: set 2 · 60 kg x 5');

    // the rest's buttons (#141), as actions that never open the app
    final actions = (details()['actions'] as List).cast<Map>();
    expect(actions.map((action) => action['id']), ['rest-minus', 'rest-plus', 'rest-skip']);
    expect(actions.map((action) => action['title']), ['-10s', '+10s', 'Skip']);
    expect(actions.map((action) => action['showsUserInterface']), everyElement(isFalse));
    // a press leaves the notification up: Android removing it reads as the
    // user's swipe, and the workout's notification was never posted again
    expect(actions.map((action) => action['cancelNotification']), everyElement(isFalse));
    // and the payload carries the rest, for the background isolate to repost from
    final payload = jsonDecode(shown()['payload'] as String) as Map;
    expect(payload['restEnd'], end.millisecondsSinceEpoch);
    expect(payload['restSkip'], 'Skip');
  });

  test('with no rest running there are no buttons: absent, not dead', () async {
    await showOngoingWorkoutNotification(workout());
    expect(details()['actions'], isNull);
  });

  /// The set up next as the snapshot names it (#246), with what follows it.
  OngoingDone upNext({int? rest = 90}) => (
    setId: 's1',
    exerciseId: 'x1',
    label: 'Done',
    afterExercise: 'Bench Press (Barbell)',
    afterNext: 'Next: set 3 · 65 kg x 5',
    restSeconds: rest,
    restLabel: 'Rest',
    restOver: 'Rest complete!',
    restMinus: '-10s',
    restPlus: '+10s',
    restSkip: 'Skip',
    restTitle: 'Rest complete!',
    restBody: '65 kg x 5',
    restSubtitle: 'Bench Press (Barbell) is next',
  );

  test('with a set to tick and no rest on the clock, Done is the one button (#246)', () async {
    await showOngoingWorkoutNotification(workout(done: upNext()));

    final actions = (details()['actions'] as List).cast<Map>();
    expect(actions.map((action) => action['id']), ['set-done']);
    expect(actions.map((action) => action['title']), ['Done']);
    expect(actions.single['cancelNotification'], isFalse);
    expect((jsonDecode(shown()['payload'] as String) as Map)['doneSetId'], 's1');
  });

  test('while resting the rest keeps its three buttons: Android allows no fourth', () async {
    final now = DateTime.now();
    await showOngoingWorkoutNotification(
      workout(
        rest: (
          start: now,
          end: now.add(const Duration(seconds: 60)),
          label: 'Rest',
          over: 'Rest complete!',
          minus: '-10s',
          plus: '+10s',
          skip: 'Skip',
        ),
        done: upNext(),
      ),
    );
    final actions = (details()['actions'] as List).cast<Map>();
    expect(actions.map((action) => action['id']), ['rest-minus', 'rest-plus', 'rest-skip']);
  });

  group('Done, pressed with no app around (#246)', () {
    Future<NotificationResponse> pressed({int? rest = 90}) async {
      await showOngoingWorkoutNotification(workout(done: upNext(rest: rest)));
      final payload = shown()['payload'] as String;
      calls.clear();
      return NotificationResponse(
        id: 2,
        actionId: 'set-done',
        payload: payload,
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
      );
    }

    test('moves on to the next set, starts the rest with its notification, and the app hears the tick', () async {
      final response = await pressed();
      final commands = <WatchCommand>[];
      final listening = ongoingNotificationCommands.listen(commands.add);
      final before = DateTime.now();

      await onOngoingNotificationAction(response);
      await pumpEventQueue();
      await listening.cancel();

      // the shade: the lines that follow, a rest counting down, its buttons
      expect(shown()['title'], 'Bench Press (Barbell)');
      expect(shown()['body'], 'Rest · Next: set 3 · 65 kg x 5');
      expect(details()['chronometerCountDown'], isTrue);
      final end = DateTime.fromMillisecondsSinceEpoch(details()['when'] as int);
      expect(end.difference(before).inSeconds, inInclusiveRange(89, 91));
      expect((details()['actions'] as List).map((action) => (action as Map)['id']), [
        'rest-minus',
        'rest-plus',
        'rest-skip',
      ]);
      expect(
        (jsonDecode(shown()['payload'] as String) as Map)['doneSetId'],
        isNull,
        reason: 'no Done until the app says what is next',
      );
      // the "rest complete" notification, as the app would have scheduled it
      final scheduled = calls.lastWhere((call) => call.method == 'zonedSchedule').arguments as Map;
      expect(scheduled['id'], 0);
      expect(scheduled['title'], 'Rest complete!');
      expect(scheduled['body'], '65 kg x 5');
      expect(scheduled['payload'], 'x1');
      // and the tick itself, for the app to make real
      expect(commands, [isA<WatchComplete>().having((c) => c.setId, 'setId', 's1')]);
    });

    test('an exercise without a rest timer moves on with no rest and no notification', () async {
      final response = await pressed(rest: null);

      await onOngoingNotificationAction(response);

      expect(shown()['body'], 'Next: set 3 · 65 kg x 5');
      expect(details()['chronometerCountDown'], isFalse);
      expect(details()['actions'], isNull);
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
    });
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
          minus: '-10s',
          plus: '+10s',
          skip: 'Skip',
        ),
      ),
    );

    expect(details()['chronometerCountDown'], isFalse);
    expect(details()['when'], started.millisecondsSinceEpoch);
  });

  test('after a pause the chronometer counts from the clock start, not the start (#134)', () async {
    final clockStart = started.add(const Duration(minutes: 5));
    await showOngoingWorkoutNotification(workout(clockStart: clockStart));

    expect(details()['usesChronometer'], isTrue);
    expect(details()['when'], clockStart.millisecondsSinceEpoch);
  });

  test('paused, there is no chronometer, and the time it stopped at is written out (#134)', () async {
    final clockStart = started.add(const Duration(minutes: 5));
    await showOngoingWorkoutNotification(
      workout(clockStart: clockStart, pausedAt: clockStart.add(const Duration(minutes: 12, seconds: 5))),
    );

    expect(details()['usesChronometer'], isFalse);
    expect(details()['showWhen'], isFalse);
    expect(shown()['body'], 'Paused · 12:05 · Next: set 2 · 60 kg x 5');
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
  test('a set stopwatch counts up from its own instant in place of rest', () async {
    final start = DateTime.now().subtract(const Duration(seconds: 65));
    await showOngoingWorkoutNotification(
      workout(
        id: 'stopwatch-test',
        stopwatch: (start: start, pausedAt: null, label: 'Set 1'),
        rest: (
          start: start,
          end: start.add(const Duration(minutes: 3)),
          label: 'Rest',
          over: 'Done',
          minus: '-10s',
          plus: '+10s',
          skip: 'Skip',
        ),
      ),
    );
    expect(details()['when'], start.millisecondsSinceEpoch);
    expect(details()['chronometerCountDown'], isFalse);
    expect(shown()['body'], 'Set 1');
  });

  test('a paused stopwatch stands still: no chronometer, its time in the text', () async {
    final start = DateTime.now().subtract(const Duration(minutes: 5));
    await showOngoingWorkoutNotification(
      workout(
        id: 'paused-stopwatch-test',
        stopwatch: (start: start, pausedAt: start.add(const Duration(seconds: 42)), label: 'Set 1 · Paused'),
      ),
    );
    expect(details()['usesChronometer'], isFalse);
    expect(shown()['body'], 'Set 1 · Paused · 0:42');
  });

  group('the rest buttons, pressed with no app around (#141)', () {
    final now = DateTime.now();
    final end = now.add(const Duration(seconds: 60));

    /// A rest on the shade, and the button [action] pressed on it — as the
    /// plugin's background isolate reports it, with the notification's own
    /// payload as the only state there is.
    Future<NotificationResponse> pressed(String action) async {
      await showOngoingWorkoutNotification(
        workout(
          rest: (
            start: now,
            end: end,
            label: 'Rest',
            over: 'Rest complete!',
            minus: '-10s',
            plus: '+10s',
            skip: 'Skip',
          ),
        ),
      );
      final payload = shown()['payload'] as String;
      calls.clear();
      return NotificationResponse(
        id: 2,
        actionId: action,
        payload: payload,
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
      );
    }

    /// Commands the main isolate hears, through the door the app opens.
    Future<List<WatchCommand>> heard(Future<void> Function() act) async {
      final commands = <WatchCommand>[];
      final listening = ongoingNotificationCommands.listen(commands.add);
      await act();
      await pumpEventQueue();
      await listening.cancel();
      return commands;
    }

    test('ten seconds on: the rest notification moves, the shade reposts, the app hears', () async {
      final response = await pressed('rest-plus');

      final commands = await heard(() => onOngoingNotificationAction(response));

      // the pending "rest complete" notification, moved
      final cancelled = calls.where((call) => call.method == 'cancel').map((call) => (call.arguments as Map)['id']);
      expect(cancelled, contains(0));
      final rescheduled = calls.lastWhere((call) => call.method == 'zonedSchedule').arguments as Map;
      expect(rescheduled['id'], 0);
      expect(rescheduled['title'], 'Rest complete!');
      expect(rescheduled['body'], '60 kg x 5');
      expect(rescheduled['payload'], 'id-bench');
      // the shade, answered at once: counting down to the moved end, buttons kept
      expect(details()['chronometerCountDown'], isTrue);
      expect(details()['when'], end.add(const Duration(seconds: 10)).millisecondsSinceEpoch);
      expect((details()['actions'] as List), hasLength(3));
      // and the app, which decides what really happened
      expect(commands, [isA<WatchAdjustRest>().having((c) => c.seconds, 'seconds', 10)]);
      expect(commands.single.workoutId, 'w1');
    });

    test('skip: the rest notification is withdrawn, the shade shows no rest, the app hears', () async {
      final response = await pressed('rest-skip');

      final commands = await heard(() => onOngoingNotificationAction(response));

      expect(calls.where((call) => call.method == 'cancel').map((call) => (call.arguments as Map)['id']), contains(0));
      expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      expect(details()['chronometerCountDown'], isFalse);
      expect(details()['actions'], isNull);
      expect(commands, [isA<WatchSkipRest>()]);
    });

    test('with no main isolate alive, the command waits for the next launch', () async {
      final response = await pressed('rest-minus');
      // the door the app opens is closed: nobody is home
      IsolateNameServer.removePortNameMapping('heart.lockScreenCommands');
      addTearDown(() => initNotifications(platform: TargetPlatform.android));

      await onOngoingNotificationAction(response);

      expect(
        await takeOngoingNotificationCommands(),
        [isA<WatchAdjustRest>().having((c) => c.seconds, 'seconds', -10)],
      );
      // taken once
      expect(await takeOngoingNotificationCommands(), isEmpty);
    });

    test('a button that is not a rest button, or a notification that is not the workout, is nothing to do', () async {
      final response = await pressed('rest-plus');

      await onOngoingNotificationAction(
        NotificationResponse(
          id: 0,
          actionId: 'rest-plus',
          payload: response.payload,
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
        ),
      );
      await onOngoingNotificationAction(
        NotificationResponse(
          id: 2,
          actionId: 'open',
          payload: response.payload,
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
        ),
      );
      // a payload from a build before the buttons: the workout's id alone
      await onOngoingNotificationAction(
        const NotificationResponse(
          id: 2,
          actionId: 'rest-plus',
          payload: 'w1',
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
        ),
      );

      expect(calls, isEmpty);
    });
  });

  group('the App Functions\' door (#289)', () {
    Future<Object?> knock(Object? arguments) async {
      const codec = StandardMethodCodec();
      Object? reply;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'heart/ongoing_workout',
        codec.encodeMethodCall(MethodCall('command', arguments)),
        (data) => reply = data == null ? null : codec.decodeEnvelope(data),
      );
      return reply;
    }

    test('a command the native side sends is taken and acknowledged', () async {
      final commands = <WatchCommand>[];
      final listening = ongoingNotificationCommands.listen(commands.add);
      addTearDown(listening.cancel);

      final taken = await knock({'action': 'startRest', 'workoutId': 'w1', 'seconds': 90, 'at': 1000});
      await Future<void>.delayed(Duration.zero);
      expect(taken, isTrue);
      expect(commands, [isA<WatchStartRest>().having((c) => c.seconds, 'seconds', 90)]);
    });

    test('nonsense is refused, not dropped on the floor', () async {
      final commands = <WatchCommand>[];
      final listening = ongoingNotificationCommands.listen(commands.add);
      addTearDown(listening.cancel);

      expect(await knock({'action': 'dance'}), isFalse);
      expect(await knock('not a map'), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(commands, isEmpty);
    });
  });
}
