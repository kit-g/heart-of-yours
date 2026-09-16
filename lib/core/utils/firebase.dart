import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/firebase_options.dart' as dev;
import 'package:heart/firebase_options_prod.dart' as prod;
import 'package:heart_state/heart_state.dart';

Future<void> initializeFirebase(Env env) {
  return Firebase.initializeApp(
    options: switch (env) {
      .dev || .test => dev.DefaultFirebaseOptions.currentPlatform,
      .prod => prod.DefaultFirebaseOptions.currentPlatform,
    },
  );
}

/// Signs out when the app is running for the first time since it was installed.
///
/// Firebase Auth keeps its refresh token in the iOS keychain, and the keychain
/// is not part of the app container: it outlives an uninstall. Nothing else
/// does — the database and the preferences go with the container — so without
/// this the app comes back from a reinstall already signed in as the previous
/// user, with their history pulled down again. That defeats "delete the app and
/// start again", which is the first thing any support conversation asks for,
/// and on a handed-on device it drops the next person into the last one's
/// account with no password. Android keeps no equivalent store and has always
/// behaved this way; this makes iOS agree.
///
/// Anonymous sessions are signed out too. They never reach the server, and
/// their rows were in the database that just went, so the uid the keychain
/// still holds points at nothing.
///
/// Called before `runApp`, so it lands before `Auth` subscribes to
/// `authStateChanges` and no restored session is ever briefly visible.
Future<void> signOutIfFirstRunAfterInstall(FirebaseAuth? firebase) {
  return Preferences.claimFirstRunAfterInstall(
    onFirstRun: () async => firebase?.signOut(),
  );
}
