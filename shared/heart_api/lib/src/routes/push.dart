part of '../api.dart';

/// The push client's routes (heart-of-yours#567, #554): registering this
/// device's token, and what reaches the account, topic by topic and person by
/// person.
mixin _PushRoutes on Requests {
  /// Registers [token], the device's FCM token, for the signed-in account.
  /// Safe to repeat: the server keeps one row per token and moves it to
  /// whichever account sent it last. [utcOffsetMinutes] is how the server
  /// places the person's evening for a daily push. The language the push is
  /// written in is the request's own `Accept-Language`.
  Future<void> registerDevice({
    required DevicePlatform platform,
    required String token,
    int? utcOffsetMinutes,
  }) async {
    final (json, code) = await post(
      Router.devices,
      body: {
        'platform': platform.value,
        'token': token,
        // the server's per-device settings, which nothing in the app sets
        'settings': const <String, dynamic>{},
        'utcOffsetMinutes': ?utcOffsetMinutes,
      },
    );
    if (code != 204) throw json;
  }

  /// Stops [token] getting the signed-in account's pushes (heart-api#415), on
  /// sign-out or when pushes turn off. Safe to repeat: a token the server holds
  /// for nobody, or for someone else, is already stopped and answers the same.
  Future<void> unregisterDevice(String token) async {
    final (json, code) = await post(Router.deviceRemovals, body: {'token': token});
    if (code != 204) throw json;
  }

  /// Every topic the account can change, in the device's language, with what
  /// each is set to, and the answers given for particular people.
  Future<PushSettings> getPushSettings() async {
    final (json, code) = await get(Router.pushSettings);
    return switch ((code, json)) {
      (200, Map json) => PushSettings.fromJson(json),
      _ => throw json,
    };
  }

  /// Sets how [topic] reaches the account, or, with [connectionId], how it
  /// reaches it from that one person.
  Future<void> setPushSetting(String topic, String delivery, {String? connectionId}) async {
    final (json, code) = await put(
      Router.pushSetting(topic),
      body: {'delivery': delivery, 'connectionId': ?connectionId},
    );
    if (code != 204) throw json;
  }

  /// Puts [topic] back to the server's default, or, with [connectionId], lets
  /// that person follow the topic again.
  Future<void> clearPushSetting(String topic, {String? connectionId}) async {
    final (json, code) = await delete(
      Router.pushSetting(topic),
      // null rather than empty: an empty map still leaves a bare `?` on the path
      query: switch (connectionId) {
        final String id => {'connectionId': id},
        null => null,
      },
    );
    if (code != 204) throw json;
  }
}
