import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart_models/heart_models.dart' show DevicePlatform;
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Push');

/// Where a silent push that arrived with the app in the background waits for
/// the next time it is in front (a list of JSON objects, oldest first).
const _pendingPushes = 'push.pending';

/// Whether this install ever let FCM make a token, so that turning off has one
/// to drop.
const _madeToken = 'push.madeToken';

/// The push client's transport (#567): the device's side of FCM, as the
/// presenter that runs it needs it. An interface so a widget test can stand
/// in for Firebase, which a test cannot reach.
abstract interface class PushClient {
  /// Lets FCM make a token and returns it, or null where the platform has
  /// none to give (an iOS simulator without APNs, a device without Play
  /// services). Never asks for the notification permission: silent pushes
  /// need none, and a visible one is asked for in context.
  Future<String?> start();

  /// Drops the token, so nothing sent to it arrives any more, and stops FCM
  /// making a new one. Turning back on makes a new token. Answers whether
  /// there was one to drop.
  Future<bool> stop();

  /// A new token for the same device, which the server needs to hear about.
  Stream<String> get tokens;

  /// A push that arrived with the app in front: data, and whether the system
  /// was given a title to show.
  Stream<({Push push, String? title})> get arrived;

  /// A push the system showed and the person tapped, the app running.
  Stream<Push> get opened;

  /// The push whose tap launched the app, once.
  Future<Push?> launchedBy();

  /// The silent pushes that arrived while the app was in the background,
  /// oldest first. Asking clears them.
  Future<List<Push>> takePending();

  /// Makes the channels the server's pushes name, in the person's language
  /// (Android; nothing elsewhere).
  Future<void> createChannels({required String comments, required String messages, required String coaching});

  /// Takes the channels down again.
  Future<void> deleteChannels();

  /// Shows a push that arrived with the app in front, where the system leaves
  /// that to the app (Android).
  Future<void> show(Push push, {required String title});

  /// The OS's own ask for notifications, once; answers whether they are
  /// allowed.
  Future<bool> askPermission({Analytics? analytics});
}

/// The background isolate FCM starts for a push that arrives with the app not
/// in front. Visible pushes the system shows by itself; a silent one is kept
/// for the app, which fetches what it names the next time it is in front.
///
/// Fetching here would mean the whole app (its database, its account, its
/// token) in an isolate of its own for a push that asks only for freshness, so
/// it waits.
@pragma('vm:entry-point')
Future<void> _onBackgroundPush(RemoteMessage message) async {
  if (message.notification != null) return;
  final push = Push.of(message.data);
  if (push == null) return;
  final prefs = await SharedPreferences.getInstance();
  final kept = prefs.getStringList(_pendingPushes) ?? const [];
  await prefs.setStringList(_pendingPushes, [...kept, jsonEncode(push.toMap())]);
}

/// [PushClient] over `firebase_messaging`.
///
/// Auto-init is off in both platforms' manifests, so before [start] no token
/// exists at all: with the coaching switches off, nothing about this device
/// reaches FCM, let alone the server.
class FirebasePushClient implements PushClient {
  final TargetPlatform platform;

  const new(this.platform);

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static bool _handlerSet = false;

  @override
  Future<void> createChannels({required String comments, required String messages, required String coaching}) {
    return createPushChannels(platform: platform, comments: comments, messages: messages, coaching: coaching);
  }

  @override
  Future<void> deleteChannels() => deletePushChannels(platform);

  @override
  Future<void> show(Push push, {required String title}) {
    return switch (platform) {
      .android => showPush(push, title: title),
      // iOS shows it itself, told so in [start]
      .iOS || .fuchsia || .linux || .macOS || .windows => Future.value(),
    };
  }

  @override
  Future<bool> askPermission({Analytics? analytics}) => ensureNotificationPermission(platform, analytics: analytics);

  @override
  Future<String?> start() async {
    if (!_handlerSet) {
      FirebaseMessaging.onBackgroundMessage(_onBackgroundPush);
      _handlerSet = true;
    }
    await (await SharedPreferences.getInstance()).setBool(_madeToken, true);
    try {
      await _messaging.setAutoInitEnabled(true);
      // iOS shows a push that arrives in front only when told to; Android
      // never does, and the presenter posts it itself
      await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      // a registration token, not the installation id `register()` would
      // give: the server sends to tokens (`send_each_for_multicast`), and an
      // installation id is not one. Moving needs the server first
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (error, stacktrace) {
      // no APNs token yet, no Play services: nothing to register, and nothing
      // the person can do about it
      _logger.warning('No push token', error, stacktrace);
      return null;
    }
  }

  @override
  Future<bool> stop() async {
    // a launch with coaching off asks this of every install: only one that
    // ever made a token has one to drop, and the rest never reach Firebase
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_madeToken) ?? false)) return false;
    await prefs.remove(_madeToken);
    try {
      await _messaging.setAutoInitEnabled(false);
      // the token's own deletion, as [start] makes a token (see there)
      // ignore: deprecated_member_use
      await _messaging.deleteToken();
    } catch (error, stacktrace) {
      _logger.warning('Push token not deleted', error, stacktrace);
    }
    return true;
  }

  @override
  // the token's own refresh, as [start] makes a token (see there)
  // ignore: deprecated_member_use
  Stream<String> get tokens => _messaging.onTokenRefresh;

  @override
  Stream<({Push push, String? title})> get arrived {
    return FirebaseMessaging.onMessage.expand(
      (message) => switch (Push.of(message.data)) {
        final Push push => [(push: push, title: message.notification?.title)],
        null => const [],
      },
    );
  }

  @override
  Stream<Push> get opened => FirebaseMessaging.onMessageOpenedApp.expand((message) => [?Push.of(message.data)]);

  @override
  Future<Push?> launchedBy() async {
    final message = await _messaging.getInitialMessage();
    return switch (message) {
      RemoteMessage(:final data) => Push.of(data),
      null => null,
    };
  }

  @override
  Future<List<Push>> takePending() async {
    final prefs = await SharedPreferences.getInstance();
    // written by another isolate: this one's cache has not seen it
    await prefs.reload();
    final kept = prefs.getStringList(_pendingPushes) ?? const [];
    if (kept.isEmpty) return const [];
    await prefs.remove(_pendingPushes);
    return kept
        .map(
          (line) => switch (jsonDecode(line)) {
            Map map => Push.of(map),
            _ => null,
          },
        )
        .nonNulls
        .toList();
  }
}

/// The platform as the server's device registry names it, or null for one it
/// takes no pushes on.
DevicePlatform? pushPlatform(TargetPlatform platform) {
  return switch (platform) {
    .iOS => .ios,
    .android => .android,
    .fuchsia || .linux || .macOS || .windows => null,
  };
}
