import 'dart:io';
import 'dart:ui';

import 'package:heart/core/env/config.dart';

Map<String, String> headers({
  String? sessionToken,
  String? appVersion,
}) {
  final version = appVersion ?? "Unknown version";
  return {
    if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': '${AppConfig.appName}/$version (${Platform.operatingSystem})',
    if (appVersion != null) 'X-App-Version': appVersion,
    'Accept-Language': PlatformDispatcher.instance.locale.toLanguageTag(),
    'X-Timezone': DateTime.now().timeZoneName,
  };
}
