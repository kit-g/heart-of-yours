import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

final _plugin = FlutterLocalNotificationsPlugin();
final _logger = Logger('Notifications');

@pragma('vm:entry-point')
void _notificationTapBackground(NotificationResponse notificationResponse) {
  _logger.info('onDidReceiveBackgroundNotificationResponse $notificationResponse');
}

Future<void> initNotifications() async {
  await _plugin.initialize(
    const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      ),
    ),
    onDidReceiveNotificationResponse: (notification) async {
      _logger.info('onDidReceiveNotificationResponse $notification');
    },
    onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
  );
}

Future<bool?> requestNotificationPermission(BuildContext context) async {
  final platform = Theme.of(context).platform;
  switch (platform) {
    case TargetPlatform.iOS:
      final platform = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      return platform?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;

    case TargetPlatform.android:
    case TargetPlatform.macOS:
    default:
      // TODO: Handle this case.
      throw UnimplementedError();
  }
}

Future<int> showNotification({
  required String title,
  required String body,
  String? subtitle,
}) async {
  var id = 0;
  return _plugin
      .show(
        id,
        title,
        body,
        NotificationDetails(
          iOS: DarwinNotificationDetails(subtitle: subtitle),
        ),
      )
      .then<int>(
        (_) => id,
      );
}
