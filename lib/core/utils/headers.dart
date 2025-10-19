import 'dart:io';
import 'dart:ui';

import 'package:heart/core/env/config.dart';

Map<String, String> headers({
  required AppConfig config,
  String? sessionToken,
  String? appVersion,
  bool isWeb = false,
}) {
  return {
    if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Language': PlatformDispatcher.instance.locale.toLanguageTag(),
    'X-Timezone': DateTime.now().timeZoneName,
    ..._common(config, appVersion, isWeb: isWeb),
  };
}

Map<String, String> imageHeaders({required AppConfig config, String? appVersion, required bool isWeb}) {
  return {
    'Accept': 'image/avif,image/webp,image/png,image/jpeg,image/gif',
    if (!isWeb) 'Accept-Encoding': 'gzip, br, deflate',
    'Cache-Control': 'public, max-age=31536000, immutable',
    ..._common(config, appVersion),
  };
}

Map<String, String> _common(AppConfig config, String? appVersion, {bool isWeb = false}) {
  final version = appVersion ?? 'Unknown version';
  return {
    if (!isWeb) 'Referer': config.appLink,
    if (!isWeb) 'User-Agent': _userAgent(config, version),
    if (appVersion != null) 'X-App-Version': appVersion,
  };
}

String _userAgent(AppConfig config, String version) {
  try {
    return '${config.appName}/$version (Flutter; ${Platform.operatingSystem}; +${config.appLink})';
  } catch (e) {
    return '${config.appName}/$version (Flutter; web; +${config.appLink})';
  }
}
