import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/firebase.dart';

import 'core/env/logging.dart';
import 'presentation/navigation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  initLogging(AppConfig.logLevel);

  await initSentry(_runner);
}

Future<void> _runner() {
  return SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then<void>(
    (_) {
      runApp(const HeartApp());
    },
  );
}
