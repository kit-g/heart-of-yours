import 'dart:io';
import 'dart:ui';

import 'package:heart/core/env/config.dart';

Map<String, String> headers({
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
    ..._common(appVersion, isWeb: isWeb),
  };
}

Map<String, String> imageHeaders({String? appVersion, required bool isWeb}) {
  return {
    'Accept': 'image/avif,image/webp,image/png,image/jpeg,image/gif',
    if (!isWeb) 'Accept-Encoding': 'gzip, br, deflate',
    'Cache-Control': 'public, max-age=31536000, immutable',
    ..._common(appVersion, isWeb: isWeb),
  };
}

Map<String, String> _common(String? appVersion, {bool isWeb = false}) {
  final version = appVersion ?? 'Unknown version';
  return {
    if (!isWeb) 'Referer': AppConfig.appLink,
    if (!isWeb) 'User-Agent': _userAgent(version),
    if (appVersion != null) 'X-App-Version': appVersion,
  };
}

String _userAgent(String version) {
  try {
    return '${AppConfig.appName}/$version (Flutter; ${Platform.operatingSystem}; +${AppConfig.appLink})';
  } catch (e) {
    return '${AppConfig.appName}/$version (Flutter; web; +${AppConfig.appLink})';
  }
}
