import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/logging.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/firebase.dart';
import 'package:heart/presentation/navigation/app.dart';
import 'package:heart_db/heart_db.dart';

Future<void> main() {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging(AppConfig.logLevel);

  return Future.wait([
    initializeFirebase(),
    LocalDatabase.init(),
  ]).then(
    (_) {
      return initSentry(_runner);
    },
  );
}

Future<void> _runner() {
  return SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then<void>(
    (_) {
      runApp(const HeartApp());
    },
  );
}
