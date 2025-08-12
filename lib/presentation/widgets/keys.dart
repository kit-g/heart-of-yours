import 'package:flutter/foundation.dart';

abstract final class AppKeys {
  const AppKeys._();

  static const profileStack = Key('AppFrame.profileStack');
  static const workoutStack = Key('AppFrame.workoutStack');
  static const historyStack = Key('AppFrame.historyStack');
  static const exercisesStack = Key('AppFrame.exercisesStack');
  static const exercisePicker = Key('App=.exercisePicker');
}
