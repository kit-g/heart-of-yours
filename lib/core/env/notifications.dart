import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

final _plugin = FlutterLocalNotificationsPlugin();
final _logger = Logger('Notifications');

const _currentExercise = 0;

@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse notificationResponse) {
  _logger.info('onDidReceiveBackgroundNotificationResponse $notificationResponse');
}

Future<void> initNotifications({
  void Function(String exerciseId)? onExerciseNotification,
  void Function(Map)? onUnknownNotification,
}) async {
  await _plugin.initialize(
    const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      ),
    ),
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

Future<bool?> requestNotificationPermission(BuildContext context) async {
  final platform = Theme.of(context).platform;
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
  required String body,
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
        ),
      )
      .then<int>(
        (_) => id,
      );
}

Future<int> showExerciseNotification({
  required String exerciseId,
  required String title,
  required String body,
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
