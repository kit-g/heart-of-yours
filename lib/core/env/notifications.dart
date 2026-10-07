import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:heart_state/heart_state.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart';

final _plugin = FlutterLocalNotificationsPlugin();
final _logger = Logger('Notifications');

const _currentExercise = 0;
const _workoutTimeout = 1;
const _ongoingWorkout = 2;

/// The status-bar icon, `res/drawable/ic_stat_heart.xml`.
///
/// A drawable rather than the launcher icon: Android masks a small icon down to
/// its alpha channel and tints the result, so a full-bleed launcher icon arrives
/// as a silhouette — the app showed a hollow ring. Flat white on transparent is
/// the only thing that survives the mask intact.
const _androidIcon = 'ic_stat_heart';

const _defaultChannelId = 'Rest Timers';
const _defaultChannelName = 'Rest Timers';

/// Its own channel because it behaves nothing like the rest-timer one: low
/// importance, so it sits in the shade without a sound or a heads-up every
/// time a set is ticked. The name is copy and comes with each update.
const _ongoingChannelId = 'Ongoing Workout';

/// The ongoing notification's rest buttons (#141): the action ids Android
/// hands back, and what each means to the rest.
const _restMinusAction = 'rest-minus';
const _restPlusAction = 'rest-plus';
const _restSkipAction = 'rest-skip';
const _restStep = 10;

/// Where the main isolate listens for the buttons (`IsolateNameServer`), and
/// where a button pressed with no main isolate alive waits for the next
/// launch (shared preferences, a list of JSON commands).
const _commandPort = 'heart.lockScreenCommands';
const _pendingCommands = 'lockScreen.pendingCommands';

/// The plugin's background entry: Android runs it on an isolate of its own,
/// with no app around it. Everything it does is [onOngoingNotificationAction],
/// which is what the tests call.
@pragma('vm:entry-point')
Future<void> _notificationTapBackground(NotificationResponse response) {
  _logger.info('onDidReceiveBackgroundNotificationResponse $response');
  return onOngoingNotificationAction(response);
}

/// A button on the ongoing notification, pressed (#141). Android runs this on
/// a background isolate of its own — the app may be in the background, or
/// not running at all — so, like the Live Activity's intents, it answers the
/// shade itself first: the "rest complete" notification is moved or
/// withdrawn, and the ongoing notification reposted with the rest as the
/// button left it. Then the command reaches the app: the main isolate if one
/// is alive, else the queue the next launch drains. Dart there applies it the
/// way the watch's are applied and reposts the truth.
///
/// Anything that is not one of the rest buttons on the ongoing notification
/// is nothing to do.
Future<void> onOngoingNotificationAction(NotificationResponse response) async {
  if (response.id != _ongoingWorkout) return;
  final int? seconds;
  switch (response.actionId) {
    case _restMinusAction:
      seconds = -_restStep;
    case _restPlusAction:
      seconds = _restStep;
    case _restSkipAction:
      seconds = null;
    default:
      return;
  }
  final shown = _OngoingDisplay.fromJson(response.payload);
  if (shown == null || shown.rest == null) return;

  final command = {
    'action': switch (seconds) {
      int() => 'adjustRest',
      null => 'skipRest',
    },
    'workoutId': shown.workoutId,
    'at': DateTime.now().millisecondsSinceEpoch,
    if (seconds case int seconds) 'seconds': seconds,
  };

  // this isolate's own plugin, initialised without callbacks: it posts and
  // schedules, nothing more
  tz.initializeTimeZones();
  await _guarded(
    () => _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings(_androidIcon)),
    ),
  );
  final adjusted = shown.adjusted(seconds);
  await _guarded(() => _moveRestNotification(adjusted.rest?.end));
  await _guarded(() => _showOngoing(adjusted));

  switch (IsolateNameServer.lookupPortByName(_commandPort)) {
    case SendPort port:
      port.send(command);
    case null:
      final prefs = await SharedPreferences.getInstance();
      final kept = prefs.getStringList(_pendingCommands) ?? const [];
      await prefs.setStringList(_pendingCommands, [...kept, jsonEncode(command)]);
  }
}

/// Moves the pending "rest complete" notification to [end], or withdraws it
/// for null. Its title and body are read back from the pending request; the
/// subtitle Android does not report is the one thing lost.
Future<void> _moveRestNotification(DateTime? end) async {
  switch (end) {
    case null:
      return _plugin.cancel(id: _currentExercise);
    case DateTime end:
      final pending = await _plugin.pendingNotificationRequests();
      final request = pending.where((request) => request.id == _currentExercise).firstOrNull;
      if (request == null) return;
      await _plugin.cancel(id: _currentExercise);
      final when = switch (end.isAfter(DateTime.now())) {
        true => end,
        false => DateTime.now().add(const Duration(seconds: 1)),
      };
      return _plugin.zonedSchedule(
        id: _currentExercise,
        title: request.title,
        body: request.body,
        scheduledDate: TZDateTime.from(when, local),
        notificationDetails: _details(title: request.title ?? '', body: request.body),
        androidScheduleMode: .exactAllowWhileIdle,
        payload: request.payload,
      );
  }
}

/// Commands from the ongoing notification's rest buttons (#141), as they
/// arrive while the app runs.
Stream<WatchCommand> get ongoingNotificationCommands => _ongoingCommands.stream;
final _ongoingCommands = StreamController<WatchCommand>.broadcast();
ReceivePort? _commands;

/// Opens the main isolate's door for the buttons; the background isolate
/// finds it by name.
void _listenForCommands() {
  if (_commands != null) return;
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(_commandPort);
  IsolateNameServer.registerPortWithName(port.sendPort, _commandPort);
  _commands = port
    ..listen((message) {
      if (message case Map map) {
        if (WatchCommand.fromMap(map) case WatchCommand command) _ongoingCommands.add(command);
      }
    });
}

/// Buttons pressed while the app was not running — oldest first. Asking
/// clears them.
Future<List<WatchCommand>> takeOngoingNotificationCommands() async {
  final prefs = await SharedPreferences.getInstance();
  final kept = prefs.getStringList(_pendingCommands) ?? const [];
  if (kept.isEmpty) return const [];
  await prefs.remove(_pendingCommands);
  return kept
      .map(
        (line) => switch (jsonDecode(line)) {
          Map map => WatchCommand.fromMap(map),
          _ => null,
        },
      )
      .nonNulls
      .toList();
}

Future<void> initNotifications({
  required TargetPlatform platform,
  void Function(String exerciseId)? onExerciseNotification,
  VoidCallback? onWorkoutTimeoutNotification,
  VoidCallback? onOngoingWorkoutNotification,
  void Function(Map)? onUnknownNotification,
  void Function(Object error, {StackTrace? stacktrace})? onError,
}) async {
  tz.initializeTimeZones();
  _report = onError;

  // One router for every tap, whether it reaches a running app or is the one
  // that launched it.
  void route(NotificationResponse notification) {
    switch (notification) {
      case NotificationResponse(:int id, :String payload) when id == _currentExercise && payload.isNotEmpty:
        return onExerciseNotification?.call(payload);
      case NotificationResponse(:int id) when id == _workoutTimeout:
        return onWorkoutTimeoutNotification?.call();
      case NotificationResponse(:int id) when id == _ongoingWorkout:
        return onOngoingWorkoutNotification?.call();
      default:
        return onUnknownNotification?.call(notification.toMap());
    }
  }

  await _createNotificationChannel(platform);
  if (platform == .android) _listenForCommands();
  // Permission is no longer requested here — we ask lazily, the first time the
  // user sets a rest timer (see [ensureNotificationPermission]). The Darwin
  // request flags are off for the same reason, so init never prompts.
  //
  // Guarded like the schedules: `initialize` resolves the status-bar drawable
  // by name too, so the same `invalid_icon` that kills a schedule killed the
  // app on start — the notifications simply do not work on such an install,
  // which is not a reason to refuse to launch.
  await _guarded(
    () => _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
        android: AndroidInitializationSettings(_androidIcon),
        macOS: DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: route,
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    ),
  );

  // A tap that *launched* the app never reaches the callback above: the plugin
  // only reports it here. Without this a cold start from any notification —
  // the rest timer, the idle reminder, the workout on the lock screen — opened
  // wherever the app would have opened anyway.
  try {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch case NotificationAppLaunchDetails(didNotificationLaunchApp: true, :final notificationResponse?)) {
      route(notificationResponse);
    }
  } on PlatformException catch (e, stacktrace) {
    _logger.warning('Notification launch details unavailable', e, stacktrace);
  }
}

/// Requests notification permission if it isn't already granted, returning
/// whether notifications are enabled afterwards. Safe to call repeatedly — the
/// OS only surfaces its prompt on the first, undecided call.
///
/// [analytics] is told only when a prompt was actually put in front of someone
/// — the already-granted path is not a decision, and counting it would report
/// a near-100% grant rate for a dialog nobody saw.
Future<bool> ensureNotificationPermission(TargetPlatform platform, {Analytics? analytics}) async {
  if (await hasNotificationsPermission(platform)) return true;
  final granted = await requestNotificationPermission(platform) ?? false;
  analytics?.notificationPermissionResult(granted: granted);
  return granted;
}

/// Nudges the user, via a snackbar, that notifications are off and offers a
/// shortcut to the OS notification settings. No-op without a [ScaffoldMessenger].
void remindNotificationsOff(
  BuildContext context, {
  required String message,
  required String settingsLabel,
}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: settingsLabel,
        onPressed: openNotificationSettings,
      ),
    ),
  );
}

/// Sends the user to the OS notification settings for this app.
void openNotificationSettings() {
  AppSettings.openAppSettings(type: AppSettingsType.notification, asAnotherTask: true);
}

/// The notifications-off nudge shown when a workout starts: what is lost, and
/// the three things the user might want to do about it.
///
/// A snackbar rather than a dialog, because it is information the user did not
/// ask for and must be able to ignore by walking past it. `SnackBarAction`
/// carries exactly one action, so the three live in the content instead — which
/// also lets them wrap, since "Never remind me" in French does not share a line
/// with anything.
///
/// [onNever] is the price of being allowed to raise this at all: a nudge with
/// no off switch is a nag, and this one appears at the top of a workout, which
/// is the worst possible moment to be argued with.
void promptNotificationsOff(
  BuildContext context, {
  required String message,
  required String enableLabel,
  required String laterLabel,
  required String neverLabel,
  required VoidCallback onNever,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  void close() => messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      content: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Text(message),
          const SizedBox(height: 4),
          Wrap(
            alignment: .end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  close();
                  onNever();
                },
                child: Text(neverLabel),
              ),
              TextButton(
                onPressed: close,
                child: Text(laterLabel),
              ),
              TextButton(
                onPressed: () {
                  close();
                  openNotificationSettings();
                },
                child: Text(enableLabel),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<bool?> requestNotificationPermission(TargetPlatform platform) async {
  return switch (platform) {
    .iOS =>
      _plugin //
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ),
    .android =>
      _plugin //
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission(),
    .macOS =>
      _plugin //
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ),
    _ => throw UnimplementedError(),
  };
}

NotificationDetails _details({
  required String title,
  String? body,
  String? subtitle,
}) {
  return NotificationDetails(
    iOS: DarwinNotificationDetails(subtitle: subtitle),
    android: AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      icon: _androidIcon,
      enableVibration: false,
      playSound: true,
      styleInformation: switch ((body, subtitle)) {
        (String b, String s) => BigTextStyleInformation('$s\n$b'),
        (String b, null) => BigTextStyleInformation(b),
        (null, String s) => BigTextStyleInformation(s),
        (null, null) => null,
      },
    ),
    macOS: DarwinNotificationDetails(subtitle: subtitle),
  );
}

Future<int> _showNotification({
  required int id,
  required String title,
  String? body,
  String? subtitle,
  String? payload,
}) async {
  final details = _details(title: title, body: body, subtitle: subtitle);
  return _plugin
      .show(id: id, title: title, body: body, notificationDetails: details, payload: payload)
      .then<int>((_) => id);
}

Future<int> showExerciseNotification({
  required String exerciseId,
  required String title,
  String? body,
  String? subtitle,
}) {
  return _showNotification(
    id: _currentExercise,
    title: title,
    body: body,
    subtitle: subtitle,
    payload: exerciseId,
  );
}

extension on NotificationResponse {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actionId': actionId,
      'input': input,
      'payload': payload,
      'notificationResponseType': notificationResponseType,
    };
  }
}

Future<void> _createNotificationChannel(TargetPlatform platform) async {
  switch (platform) {
    case .android:
      const channel = AndroidNotificationChannel(
        _defaultChannelId,
        _defaultChannelName,
        description: 'This channel is used for important notifications',
        importance: .defaultImportance,
      );

      return _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    default:
  }
}

Future<bool> hasNotificationsPermission(TargetPlatform platform) async {
  switch (platform) {
    case .android:
      final enabled =
          await _plugin //
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled();
      return enabled ?? false;
    case .iOS:
      final options =
          await _plugin //
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();
      return options?.isEnabled ?? false;
    case .macOS:
      final options =
          await _plugin //
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
              ?.checkPermissions();
      return options?.isEnabled ?? false;
    default:
      return false;
  }
}

/// Where a notification failure that is not a refusal is reported, on top of
/// the log every one of them gets.
///
/// Wired to Sentry by [initNotifications]; a test substitutes its own to assert
/// what got reported. Null is a real state, not just a test's: [initNotifications]
/// only runs when the app asked for local notifications, so on the web and in
/// widget tests nobody is listening — which is exactly why [_guarded] logs
/// first and reports second, instead of letting the failure evaporate when
/// this happens to be unset.
void Function(Object error, {StackTrace? stacktrace})? _report;

/// Runs a notification-plugin call and never lets it reach the zone.
///
/// Two kinds of failure arrive here and they deserve opposite treatment.
///
/// **The user declined.** iOS refuses to store a notification for an app
/// without permission — `PlatformException(Error 2003, Repository could not
/// save notification. Source is not authorized., UNErrorDomain)`. That is an
/// answer, not a fault: they chose it, the workout is already saved, and there
/// is nothing to tell them. Swallowed silently.
///
/// **Everything else**, of which the live example is `invalid_icon` — the
/// plugin resolves the status-bar drawable by name through
/// `getIdentifier(name, "drawable", getPackageName())`, and on some installs
/// that returns 0 for a resource that is demonstrably in the APK under exactly
/// that name and package. It is reported, and then swallowed too.
///
/// Reported-and-swallowed rather than rethrown, which is what this used to do.
/// Nothing awaits these calls, so a throw became an unhandled error on the
/// zone — recorded fatal, on the screen that ends a workout and, through
/// `initialize`, on app start. The app cannot repair a resource table it did
/// not break, and a notification that will not schedule is not worth taking the
/// screen down for. Reporting keeps the signal we would otherwise lose by
/// silencing it; not rethrowing stops it being a crash.
Future<void> _guarded(Future<void> Function() request) async {
  try {
    await request();
  } on PlatformException catch (e, stacktrace) {
    final refused = e.code.contains('2003') || (e.message?.contains('not authorized') ?? false);
    if (refused) return;

    _logger.severe('Notification call failed', e, stacktrace);
    _report?.call(e, stacktrace: stacktrace);
  }
}

Future<void> scheduleExerciseNotification(
  String exerciseId,
  DateTime time, {
  required String title,
  String? body,
  String? subtitle,
}) async {
  final delay = time.difference(DateTime.now());
  if (delay.isNegative) return;

  final details = _details(title: title, body: body, subtitle: subtitle);
  return _guarded(
    () => _plugin.zonedSchedule(
      id: _currentExercise,
      title: title,
      body: body,
      scheduledDate: TZDateTime.from(time, local),
      notificationDetails: details,
      androidScheduleMode: .exactAllowWhileIdle,
      payload: exerciseId,
    ),
  );
}

/// Schedules the "you've gone idle" notification for an active workout at
/// [time]. Re-scheduling replaces any pending one (same id), so the caller
/// pushes the deadline forward simply by calling this again.
Future<void> scheduleWorkoutTimeoutNotification(
  DateTime time, {
  required String title,
  String? body,
}) async {
  final delay = time.difference(DateTime.now());
  if (delay.isNegative) return;

  final details = _details(title: title, body: body);
  return _guarded(
    () => _plugin.zonedSchedule(
      id: _workoutTimeout,
      title: title,
      body: body,
      scheduledDate: TZDateTime.from(time, local),
      notificationDetails: details,
      androidScheduleMode: .exactAllowWhileIdle,
    ),
  );
}

Future<void> cancelWorkoutTimeoutNotification() {
  return _plugin.cancel(id: _workoutTimeout);
}

/// Withdraws the pending "rest complete" notification — the counterpart of a
/// skipped rest timer. Narrower than [cancelAllNotifications] on purpose: the
/// workout-timeout notification must survive a skip.
Future<void> cancelExerciseNotification() {
  return _plugin.cancel(id: _currentExercise);
}

/// Shows [workout] as Android's ongoing notification (#133), or updates the
/// one already up — same id, so there is only ever one.
///
/// The clock is the notification's own chronometer: counting up from the
/// workout's start, or — while resting — down to the rest's end. Android draws
/// one chronometer per notification, which is why rest *replaces* the elapsed
/// time here instead of sitting beside it as on the Live Activity. When the
/// rest runs out the app puts the elapsed clock back; if the process was
/// frozen by then, the countdown shows a negative until the next update, and
/// the "rest complete" notification has already said the same thing louder.
///
/// Not pinned: the user can swipe it away, and a swipe holds for the rest of
/// that workout — see [_ongoingDismissedFor]. A notification that comes back
/// every time a set is ticked would be worse than none. It otherwise goes when
/// the workout does ([cancelOngoingWorkoutNotification]). Nothing here needs a
/// foreground service — the chronometer ticks without the app.
///
/// Paused (#134), there is no clock to count: a chronometer cannot be stopped,
/// so it goes, and the time it stopped at is written into the text instead.
Future<void> showOngoingWorkoutNotification(OngoingWorkout workout) {
  return _showOngoing(_OngoingDisplay.of(workout));
}

/// What the ongoing notification shows, as both the app and the buttons'
/// background isolate (#141) post it: the latter has only the notification's
/// own payload to go on, so this is what the payload carries.
final class _OngoingDisplay {
  final String workoutId;
  final String title;
  final String exercise;
  final String next;
  final DateTime clockStart;
  final DateTime? pausedAt;
  final String pausedLabel;
  final OngoingRest? rest;
  final ({DateTime start, DateTime? pausedAt, String label})? stopwatch;
  final Color color;
  final String channel;

  const new({
    required this.workoutId,
    required this.title,
    required this.exercise,
    required this.next,
    required this.clockStart,
    required this.pausedAt,
    required this.pausedLabel,
    required this.rest,
    required this.stopwatch,
    required this.color,
    required this.channel,
  });

  factory of(OngoingWorkout workout) {
    return _OngoingDisplay(
      workoutId: workout.workoutId,
      title: workout.title,
      exercise: workout.exercise,
      next: workout.next,
      clockStart: workout.clockStart,
      pausedAt: workout.pausedAt,
      pausedLabel: workout.pausedLabel,
      rest: workout.rest,
      stopwatch: workout.stopwatch,
      color: workout.preset.light.accentInk,
      channel: workout.channel,
    );
  }

  /// The same display with the rest moved by [seconds], or over for null.
  _OngoingDisplay adjusted(int? seconds) {
    return _OngoingDisplay(
      workoutId: workoutId,
      title: title,
      exercise: exercise,
      next: next,
      clockStart: clockStart,
      pausedAt: pausedAt,
      pausedLabel: pausedLabel,
      rest: switch ((rest, seconds)) {
        (OngoingRest rest, int seconds) => (
          start: rest.start,
          end: rest.end.add(Duration(seconds: seconds)),
          label: rest.label,
          over: rest.over,
          minus: rest.minus,
          plus: rest.plus,
          skip: rest.skip,
        ),
        _ => null,
      },
      stopwatch: stopwatch,
      color: color,
      channel: channel,
    );
  }

  String toJson() {
    return jsonEncode({
      'workoutId': workoutId,
      'title': title,
      'exercise': exercise,
      'next': next,
      'clockStart': clockStart.millisecondsSinceEpoch,
      'pausedAt': ?pausedAt?.millisecondsSinceEpoch,
      'pausedLabel': pausedLabel,
      if (rest case OngoingRest rest) ...{
        'restStart': rest.start.millisecondsSinceEpoch,
        'restEnd': rest.end.millisecondsSinceEpoch,
        'restLabel': rest.label,
        'restOver': rest.over,
        'restMinus': rest.minus,
        'restPlus': rest.plus,
        'restSkip': rest.skip,
      },
      if (stopwatch case final clock?) ...{
        'stopwatchStart': clock.start.millisecondsSinceEpoch,
        'stopwatchLabel': clock.label,
        'stopwatchPausedAt': ?clock.pausedAt?.millisecondsSinceEpoch,
      },
      'color': color.toARGB32(),
      'channel': channel,
    });
  }

  /// Null for a payload that is not one of these — a build before the
  /// buttons posted the workout's id alone.
  static _OngoingDisplay? fromJson(String? payload) {
    if (payload == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    DateTime at(Object? millis) => DateTime.fromMillisecondsSinceEpoch(millis as int);
    return switch (decoded) {
      {
            'workoutId': String workoutId,
            'title': String title,
            'exercise': String exercise,
            'next': String next,
            'clockStart': int clockStart,
            'pausedLabel': String pausedLabel,
            'color': int color,
            'channel': String channel,
          } &&
          final Map map =>
        _OngoingDisplay(
          workoutId: workoutId,
          title: title,
          exercise: exercise,
          next: next,
          clockStart: at(clockStart),
          pausedAt: switch (map['pausedAt']) {
            int millis => at(millis),
            _ => null,
          },
          pausedLabel: pausedLabel,
          rest: switch (map) {
            {
              'restStart': int start,
              'restEnd': int end,
              'restLabel': String label,
              'restOver': String over,
              'restMinus': String minus,
              'restPlus': String plus,
              'restSkip': String skip,
            } =>
              (start: at(start), end: at(end), label: label, over: over, minus: minus, plus: plus, skip: skip),
            _ => null,
          },
          stopwatch: switch (map) {
            {'stopwatchStart': int start, 'stopwatchLabel': String label} => (
              start: at(start),
              pausedAt: switch (map['stopwatchPausedAt']) {
                int millis => at(millis),
                _ => null,
              },
              label: label,
            ),
            _ => null,
          },
          color: Color(color),
          channel: channel,
        ),
      _ => null,
    };
  }
}

/// Posts [workout] as Android's ongoing notification (#133), or updates the
/// one already up — same id, so there is only ever one.
///
/// The clock is the notification's own chronometer: counting up from the
/// workout's start, or — while resting — down to the rest's end. Android draws
/// one chronometer per notification, which is why rest *replaces* the elapsed
/// time here instead of sitting beside it as on the Live Activity. When the
/// rest runs out the app puts the elapsed clock back; if the process was
/// frozen by then, the countdown shows a negative until the next update, and
/// the "rest complete" notification has already said the same thing louder.
///
/// While resting, the rest's buttons (#141) are the notification's actions:
/// they land on [_notificationTapBackground] without opening the app.
///
/// Not pinned: the user can swipe it away, and a swipe holds for the rest of
/// that workout — see [_ongoingDismissedFor]. A notification that comes back
/// every time a set is ticked would be worse than none. It otherwise goes when
/// the workout does ([cancelOngoingWorkoutNotification]). Nothing here needs a
/// foreground service — the chronometer ticks without the app.
///
/// Paused (#134), there is no clock to count: a chronometer cannot be stopped,
/// so it goes, and the time it stopped at is written into the text instead.
Future<void> _showOngoing(_OngoingDisplay workout) {
  final resting =
      workout.stopwatch == null &&
      switch (workout.rest) {
        OngoingRest(:final end) => end.isAfter(DateTime.now()),
        null => false,
      };
  // a chronometer cannot stand still, so a stopped clock — the workout's
  // (#134) or a set's stopwatch (#171) — is its time in words
  final (clock, body) = switch ((workout.pausedAt, workout.stopwatch, resting, workout.rest)) {
    (DateTime at, _, _, _) => (
      null,
      [
        workout.pausedLabel,
        formatClock(at.difference(workout.clockStart)),
        if (workout.next.isNotEmpty) workout.next,
      ].join(' · '),
    ),
    (null, final stopwatch?, _, _) => switch (stopwatch.pausedAt) {
      DateTime at => (null, '${stopwatch.label} · ${_clockText(at.difference(stopwatch.start))}'),
      null => (stopwatch.start, stopwatch.label),
    },
    (null, null, true, OngoingRest(:final end, :final label)) => (end, '$label · ${workout.next}'),
    _ => (workout.clockStart, workout.next),
  };

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _ongoingChannelId,
      workout.channel,
      icon: _androidIcon,
      color: workout.color,
      importance: .low,
      priority: .low,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      playSound: false,
      enableVibration: false,
      showWhen: clock != null,
      when: clock?.millisecondsSinceEpoch,
      usesChronometer: clock != null,
      chronometerCountDown: resting,
      subText: workout.title,
      visibility: .public,
      category: .progress,
      actions: switch ((resting, workout.rest)) {
        (true, OngoingRest rest) => [
          AndroidNotificationAction(_restMinusAction, rest.minus, showsUserInterface: false),
          AndroidNotificationAction(_restPlusAction, rest.plus, showsUserInterface: false),
          AndroidNotificationAction(_restSkipAction, rest.skip, showsUserInterface: false),
        ],
        _ => null,
      },
    ),
  );

  return _guarded(
    () async {
      if (workout.workoutId == _ongoingDismissedFor) return;
      if (workout.workoutId == _ongoingShownFor && !await _isOngoingShowing()) {
        _ongoingDismissedFor = workout.workoutId;
        return;
      }

      await _ensureOngoingChannel(workout.channel);
      await _plugin.show(
        id: _ongoingWorkout,
        title: workout.exercise,
        body: body,
        notificationDetails: details,
        payload: workout.toJson(),
      );
      _ongoingShownFor = workout.workoutId;
    },
  );
}

/// The workout the ongoing notification was last posted for, in this process.
String? _ongoingShownFor;

/// A workout whose ongoing notification the user swiped away.
///
/// Android says nothing when that happens, so it is inferred: posted for this
/// workout, and no longer among the app's active notifications. From then on
/// the workout stays off the shade and the lock screen — the next one gets it
/// again. In memory only, so a process restarted mid-workout posts it once
/// more; the swipe it would take to dismiss it again is the cost.
String? _ongoingDismissedFor;

/// Whether the ongoing notification is still up. Assumes it is when the
/// platform cannot say, so an unanswerable question never silences it.
Future<bool> _isOngoingShowing() async {
  try {
    final active = await _plugin.getActiveNotifications();
    return active.any((notification) => notification.id == _ongoingWorkout);
  } on PlatformException {
    return true;
  }
}

/// The name [_ongoingChannelId] was last created under, in this process.
String? _ongoingChannelName;

/// Creates the ongoing-workout channel, or renames it after a language change.
///
/// Explicit because the plugin's per-notification channel handling cannot do
/// both: its default creates a missing channel but never renames one, and
/// `channelAction: .update` renames an existing channel but never creates a
/// missing one — the notification is then posted to nothing and silently
/// dropped. Android's own `createNotificationChannel` does both.
Future<void> _ensureOngoingChannel(String name) async {
  if (name == _ongoingChannelName) return;
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        AndroidNotificationChannel(
          _ongoingChannelId,
          name,
          importance: .low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
  _ongoingChannelName = name;
}

Future<void> cancelOngoingWorkoutNotification() {
  _ongoingShownFor = null;
  return _guarded(() => _plugin.cancel(id: _ongoingWorkout));
}

Future<void> cancelAllNotifications() {
  return _plugin.cancelAll();
}

/// [elapsed] as a stopped clock reads, "0:42" or "1:02:03".
String _clockText(Duration elapsed) {
  final seconds = elapsed.inSeconds % 60;
  final minutes = elapsed.inMinutes % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return switch (elapsed.inHours) {
    0 => '$minutes:${two(seconds)}',
    final hours => '$hours:${two(minutes)}:${two(seconds)}',
  };
}
