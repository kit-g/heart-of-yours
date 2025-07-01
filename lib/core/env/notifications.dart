import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

final _plugin = FlutterLocalNotificationsPlugin();
final _logger = Logger('Notifications');

const _currentExercise = 0;
const _defaultChannelId = 'Rest Timers';
const _defaultChannelName = 'Rest Timers';

@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse notificationResponse) {
  _logger.info('onDidReceiveBackgroundNotificationResponse $notificationResponse');
}

Future<void> initNotifications({
  required TargetPlatform platform,
  void Function(String exerciseId)? onExerciseNotification,
  void Function(Map)? onUnknownNotification,
}) async {
  await _createNotificationChannel(platform);
  await requestNotificationPermission(platform);
  await _plugin.initialize(
    const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        macOS: DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        )),
    onDidReceiveNotificationResponse: (notification) async {
      switch (notification) {
        case NotificationResponse(:int id, :String payload) when id == _currentExercise && payload.isNotEmpty:
          return onExerciseNotification?.call(payload);
        default:
          return onUnknownNotification?.call(notification.toMap());
      }
    },
    onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
  );
}

Future<bool?> requestNotificationPermission(TargetPlatform platform) async {
  return switch (platform) {
    TargetPlatform.iOS => _plugin //
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ),
    TargetPlatform.android => _plugin //
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission(),
    TargetPlatform.macOS => _plugin //
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ),
    _ => throw UnimplementedError()
  };
}

Future<int> _showNotification({
  required int id,
  required String title,
  String? body,
  String? subtitle,
  String? payload,
}) async {
  return _plugin
      .show(
        id,
        title,
        body,
        payload: payload,
        NotificationDetails(
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
        ),
      )
      .then<int>(
        (_) => id,
      );
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
    case TargetPlatform.android:
      const channel = AndroidNotificationChannel(
        _defaultChannelId,
        _defaultChannelName,
        description: 'This channel is used for important notifications',
        importance: Importance.defaultImportance,
      );

      return _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    default:
  }
}

Future<bool> hasNotificationsPermission(TargetPlatform platform) async {
  switch (platform) {
    case TargetPlatform.android:
      final enabled = await _plugin //
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    case TargetPlatform.iOS:
      final options = await _plugin //
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled ?? false;
    case TargetPlatform.macOS:
      final options = await _plugin //
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled ?? false;
    default:
      return false;
  }
}
