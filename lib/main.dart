import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/logging.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/firebase.dart';
import 'package:heart/presentation/navigation/app.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';

typedef AppRunner =
    Future<void> Function({
      required AppConfig appConfig,
      required LocalDatabase db,
      required Api api,
      required ConfigApi config,
      bool? hasLocalNotifications,
    });

@visibleForTesting
Future<void> bootstrap({
  required AppConfig appConfig,
  Future<void> Function() initializeFirebase = initializeFirebase,
  Future<LocalDatabase> Function() initDb = LocalDatabase.init,
  SentryInit? initSentry = initSentry,
  AppRunner appRunner = _runner,
  LogInit? initLogging = initLogging,
  bool? hasLocalNotifications,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging?.call(appConfig.logLevel);

  final api = Api(gateway: appConfig.api);
  final config = ConfigApi(gateway: appConfig.mediaLink);

  return Future.wait<void>([
    initializeFirebase(),
    initDb(),
  ]).then<void>(
    (initialized) {
      final [_, db] = initialized;
      final starter = appRunner(
        db: db as LocalDatabase,
        api: api,
        config: config,
        hasLocalNotifications: hasLocalNotifications,
        appConfig: appConfig,
      );
      return switch (initSentry) {
        FutureOr<void> Function(Future<void> Function(), AppConfig) callback => callback(() => starter, appConfig),
        null => starter,
      };
    },
  );
}

Future<void> _runner({
  required Api api,
  required AppConfig appConfig,
  required ConfigApi config,
  required LocalDatabase db,
  bool? hasLocalNotifications,
  Future<void> Function(List<DeviceOrientation> orientations) setOrientations = SystemChrome.setPreferredOrientations,
}) {
  return setOrientations([DeviceOrientation.portraitUp]).then<void>(
    (_) {
      return runApp(
        HeartApp(
          db: db,
          api: api,
          config: config,
          hasLocalNotifications: hasLocalNotifications,
          appConfig: appConfig,
        ),
      );
    },
  );
}

Future<void> main() {
  return bootstrap(appConfig: AppConfig.fromDartDefine());
}
