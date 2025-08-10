import 'dart:io';
import 'dart:ui';

import 'package:heart/core/env/config.dart';

Map<String, String> headers({
  String? sessionToken,
  String? appVersion,
}) {
  return {
    if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Language': PlatformDispatcher.instance.locale.toLanguageTag(),
    'X-Timezone': DateTime.now().timeZoneName,
    ..._common(appVersion),
  };
}

Map<String, String> imageHeaders({String? appVersion}) {
  return {
    'Accept': 'image/avif,image/webp,image/png,image/jpeg,image/gif',
    'Accept-Encoding': 'gzip, br, deflate',
    'Cache-Control': 'public, max-age=31536000, immutable',
    ..._common(appVersion),
  };
}

Map<String, String> _common(String? appVersion) {
  final version = appVersion ?? 'Unknown version';
  return {
    'Referer': AppConfig.appLink,
    'User-Agent': _userAgent(version),
    if (appVersion != null) 'X-App-Version': appVersion,
  };
}

String _userAgent(String version) {
  return '${AppConfig.appName}/$version (Flutter; ${Platform.operatingSystem}; +${AppConfig.appLink})';
}
