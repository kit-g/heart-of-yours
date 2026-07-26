import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart';

final _plugin = FlutterLocalNotificationsPlugin();
final _logger = Logger('Notifications');

const _currentExercise = 0;
const _workoutTimeout = 1;
const _defaultChannelId = 'Rest Timers';
const _defaultChannelName = 'Rest Timers';

@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse notificationResponse) {
  _logger.info('onDidReceiveBackgroundNotificationResponse $notificationResponse');
}

Future<void> initNotifications({
  required TargetPlatform platform,
  void Function(String exerciseId)? onExerciseNotification,
  VoidCallback? onWorkoutTimeoutNotification,
  void Function(Map)? onUnknownNotification,
}) async {
  tz.initializeTimeZones();

  await _createNotificationChannel(platform);
  // Permission is no longer requested here — we ask lazily, the first time the
  // user sets a rest timer (see [ensureNotificationPermission]). The Darwin
  // request flags are off for the same reason, so init never prompts.
  await _plugin.initialize(
    settings: const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestSoundPermission: false,
        requestBadgePermission: false,
        requestAlertPermission: false,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
        default:
          return onUnknownNotification?.call(notification.toMap());
      }
    },
    onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
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
        onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.notification, asAnotherTask: true),
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
      icon: '@mipmap/ic_launcher',
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
  return _plugin.zonedSchedule(
    id: 0,
    title: title,
    body: body,
    scheduledDate: TZDateTime.from(time, local),
    notificationDetails: details,
    androidScheduleMode: .exactAllowWhileIdle,
    payload: exerciseId,
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
  return _plugin.zonedSchedule(
    id: _workoutTimeout,
    title: title,
    body: body,
    scheduledDate: TZDateTime.from(time, local),
    notificationDetails: details,
    androidScheduleMode: .exactAllowWhileIdle,
  );
}

Future<void> cancelWorkoutTimeoutNotification() {
  return _plugin.cancel(id: _workoutTimeout);
}

Future<void> cancelAllNotifications() {
  return _plugin.cancelAll();
}
