import 'package:flutter/material.dart';

import 'alarms.dart';
import 'auth.dart';
import 'exercises.dart';
import 'stats.dart';
import 'templates.dart';
import 'timers.dart';
import 'workouts.dart';

void clearState(BuildContext context) {
  Alarms.of(context).onSignOut();
  Auth.of(context).onSignOut();
  Exercises.of(context).onSignOut();
  Stats.of(context).onSignOut();
  Templates.of(context).onSignOut();
  Timers.of(context).onSignOut();
  Workouts.of(context).onSignOut();
}
