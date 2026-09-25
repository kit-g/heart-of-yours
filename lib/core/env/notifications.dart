import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:logging/logging.dart';
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

@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse notificationResponse) {
  _logger.info('onDidReceiveBackgroundNotificationResponse $notificationResponse');
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

  await _createNotificationChannel(platform);
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
      onDidReceiveNotificationResponse: (notification) async {
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
      },
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    ),
  );
}

/// Requests notification permission if it isn't already granted, returning
/// whether notifications are enabled afterwards. Safe to call repeatedly — the
/// OS only surfaces its prompt on the first, undecided call.
Future<bool> ensureNotificationPermission(TargetPlatform platform) async {
  if (await hasNotificationsPermission(platform)) return true;
  return await requestNotificationPermission(platform) ?? false;
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
Future<void> showOngoingWorkoutNotification(OngoingWorkout workout) {
  final resting = switch (workout.rest) {
    OngoingRest(:final end) => end.isAfter(DateTime.now()),
    null => false,
  };
  final (clock, body) = switch ((resting, workout.rest)) {
    (true, OngoingRest(:final end, :final label)) => (end, '$label · ${workout.next}'),
    _ => (workout.startedAt, workout.next),
  };

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _ongoingChannelId,
      workout.channel,
      icon: _androidIcon,
      color: workout.preset.light.accentInk,
      importance: .low,
      priority: .low,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      playSound: false,
      enableVibration: false,
      showWhen: true,
      when: clock.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: resting,
      subText: workout.title,
      visibility: .public,
      category: .progress,
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
        payload: workout.workoutId,
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
