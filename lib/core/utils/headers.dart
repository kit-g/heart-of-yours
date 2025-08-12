import 'dart:io';
import 'dart:ui';

import 'package:heart/core/env/config.dart';

Map<String, String> headers({
  required AppConfig config,
  String? sessionToken,
  String? appVersion,
}) {
  return {
    if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Language': PlatformDispatcher.instance.locale.toLanguageTag(),
    'X-Timezone': DateTime.now().timeZoneName,
    ..._common(config, appVersion),
  };
}

Map<String, String> imageHeaders({required AppConfig config, String? appVersion}) {
  return {
    'Accept': 'image/avif,image/webp,image/png,image/jpeg,image/gif',
    'Accept-Encoding': 'gzip, br, deflate',
    'Cache-Control': 'public, max-age=31536000, immutable',
    ..._common(config, appVersion),
  };
}

Map<String, String> _common(AppConfig config, String? appVersion) {
  final version = appVersion ?? 'Unknown version';
  return {
    'Referer': config.appLink,
    'User-Agent': _userAgent(config, version),
    if (appVersion != null) 'X-App-Version': appVersion,
  };
}

String _userAgent(AppConfig config, String version) {
  return '${config.appName}/$version (Flutter; ${Platform.operatingSystem}; +${config.appLink})';
}
