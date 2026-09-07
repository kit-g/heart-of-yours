import 'package:flutter/material.dart';

import 'alarms.dart';
import 'auth.dart';
import 'backfill.dart';
import 'charts.dart';
import 'config.dart';
import 'exercises.dart';
import 'goals.dart';
import 'health.dart';
import 'preferences.dart';
import 'previous.dart';
import 'stats.dart';
import 'templates.dart';
import 'timers.dart';
import 'upsync.dart';
import 'workouts.dart';

/// Signs out and forgets everything the session held.
void clearState(BuildContext context) {
  clearUserState(context);
  Auth.of(context).onSignOut();
}

/// Erases everything an anonymous session holds on the device and signs it
/// out, so the app starts over under a fresh uid.
///
/// The memory is cleared first: nothing a notifier still holds may be written
/// back once the rows are gone. Then the uid's rows and preferences, then the
/// session — which on mobile is replaced by a new anonymous one at once (see
/// [Auth.ensureSession]). Nothing happens for a session with an account: that
/// one has account deletion, and [Auth.eraseSession] refuses it.
Future<void> eraseState(BuildContext context) async {
  final auth = Auth.of(context);
  if (!auth.isAnonymous) return;
  if (auth.user?.id case String uid) {
    final preferences = Preferences.of(context);
    clearUserState(context);
    await preferences.forgetUser(uid);
    await auth.eraseSession();
  }
}

/// Forgets everything the session held, keeping the session itself.
///
/// What a uid switch needs: an account signed into from an anonymous session
/// replaces it under the same running app, and nothing the anonymous uid held
/// in memory — its workouts, templates, catalog units — may bleed into the
/// account's lists or, worse, get pushed to its server as pending writes.
void clearUserState(BuildContext context) {
  Alarms.of(context).onSignOut();
  Backfill.of(context).onSignOut();
  Charts.of(context).onSignOut();
  Exercises.of(context).onSignOut();
  Goals.of(context).onSignOut();
  Health.of(context).onSignOut();
  PreviousExercises.of(context).onSignOut();
  RemoteConfig.of(context).onSignOut();
  Stats.of(context).onSignOut();
  Templates.of(context).onSignOut();
  Timers.of(context).onSignOut();
  Upsync.of(context).onSignOut();
  Workouts.of(context).onSignOut();
}
