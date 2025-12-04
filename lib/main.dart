import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/logging.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/firebase.dart';
import 'package:heart/presentation/navigation/app.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef AppRunner =
    Future<void> Function({
      required AppConfig appConfig,
      required LocalDatabase db,
      required Api api,
      required ConfigApi config,
      bool? hasLocalNotifications,
      FirebaseAuth? firebase,
    });

@visibleForTesting
Future<void> bootstrap({
  required AppConfig appConfig,
  Future<void> Function() initFirebase = initializeFirebase,
  Future<LocalDatabase> Function() initDb = LocalDatabase.init,
  SentryInit? initSentry = initSentry,
  AppRunner appRunner = _runner,
  LogInit? initLogging = initLogging,
  bool? hasLocalNotifications,
  FirebaseAuth? firebase,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging?.call(appConfig.logLevel);

  final api = Api(gateway: appConfig.api);
  final config = ConfigApi(gateway: appConfig.mediaLink);

  return Future.wait<void>([
    initFirebase(),
    initDb(),
  ]).then<void>(
    (initialized) {
      final [_, db] = initialized;

      Future<void> run() {
        return appRunner(
          db: db as LocalDatabase,
          api: api,
          config: config,
          hasLocalNotifications: hasLocalNotifications,
          appConfig: appConfig,
          firebase: firebase,
        );
      }

      return switch (initSentry) {
        FutureOr<void> Function(Future<void> Function(), AppConfig) callback => callback(run, appConfig),
        null => run(),
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
  FirebaseAuth? firebase,
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
          firebaseAuth: firebase,
          router: HeartRouter(
            observers: [
              SentryNavigatorObserver(),
              FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> main() {
  return bootstrap(
    appConfig: AppConfig.fromDartDefine(),
    hasLocalNotifications: true,
  );
}
