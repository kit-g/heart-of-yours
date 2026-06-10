import 'package:firebase_core/firebase_core.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/firebase_options.dart' as dev;
import 'package:heart/firebase_options_prod.dart' as prod;

Future<void> initializeFirebase(Env env) {
  return Firebase.initializeApp(
    options: switch (env) {
      .dev || .test => dev.DefaultFirebaseOptions.currentPlatform,
      .prod => prod.DefaultFirebaseOptions.currentPlatform,
    },
  );
}
