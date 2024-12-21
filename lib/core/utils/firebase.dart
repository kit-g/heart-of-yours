import 'package:firebase_core/firebase_core.dart';
import 'package:heart/firebase_options.dart';

Future<FirebaseApp> initializeFirebase() {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
