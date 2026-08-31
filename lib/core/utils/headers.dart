import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:heart/core/env/config.dart';

/// The BCP-47 tag `Accept-Language` states on every API request — the raw
/// device locale ([locale] when the caller already holds a fresher one, e.g.
/// from `didChangeLocales`), deliberately not the app's resolved UI locale:
/// the contract is "state what the user speaks, the server serves the best
/// content it has", so localized content can lead the UI chrome translation.
///
/// Locale is resolved server-side per request and nothing is stored there; on
/// a device language change, re-send the header and re-fetch (see
/// `Exercises.onLocaleChanged`). Read through the binding's dispatcher, which
/// is also what test bindings can steer.
String languageTag([Locale? locale]) {
  return (locale ?? WidgetsBinding.instance.platformDispatcher.locale).toLanguageTag();
}

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
    'Accept-Language': languageTag(),
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
    'X-App-Version': ?appVersion,
  };
}

String _userAgent(AppConfig config, String version) {
  try {
    return '${config.appName}/$version (Flutter; ${Platform.operatingSystem}; +${config.appLink})';
  } catch (e) {
    return '${config.appName}/$version (Flutter; web; +${config.appLink})';
  }
}
