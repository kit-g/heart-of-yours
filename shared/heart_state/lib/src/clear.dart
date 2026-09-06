import 'package:flutter/material.dart';

import 'alarms.dart';
import 'auth.dart';
import 'charts.dart';
import 'config.dart';
import 'exercises.dart';
import 'goals.dart';
import 'health.dart';
import 'previous.dart';
import 'stats.dart';
import 'templates.dart';
import 'timers.dart';
import 'workouts.dart';

/// Signs out and forgets everything the session held.
void clearState(BuildContext context) {
  clearUserState(context);
  Auth.of(context).onSignOut();
}

/// Forgets everything the session held, keeping the session itself.
///
/// What a uid switch needs: an account signed into from an anonymous session
/// replaces it under the same running app, and nothing the anonymous uid held
/// in memory — its workouts, templates, catalog units — may bleed into the
/// account's lists or, worse, get pushed to its server as pending writes.
void clearUserState(BuildContext context) {
  Alarms.of(context).onSignOut();
  Charts.of(context).onSignOut();
  Exercises.of(context).onSignOut();
  Goals.of(context).onSignOut();
  Health.of(context).onSignOut();
  PreviousExercises.of(context).onSignOut();
  RemoteConfig.of(context).onSignOut();
  Stats.of(context).onSignOut();
  Templates.of(context).onSignOut();
  Timers.of(context).onSignOut();
  Workouts.of(context).onSignOut();
}
