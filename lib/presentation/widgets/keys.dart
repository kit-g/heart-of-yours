import 'package:flutter/foundation.dart';

abstract final class AppKeys {
  const AppKeys._();

  static const profileStack = Key('AppFrame.profileStack');
  static const workoutStack = Key('AppFrame.workoutStack');
  static const historyStack = Key('AppFrame.historyStack');
  static const exercisesStack = Key('AppFrame.exercisesStack');
  static const exercisePicker = Key('AppFrame.exercisePicker');

  /// The navigation rail, present only in the wide layout. Its absence is how a
  /// test tells it is looking at the compact frame.
  static const navigationRail = Key('AppFrame.navigationRail');

  /// Placeholder holding a two-pane detail open before anything is selected.
  /// Asserting on it distinguishes "nothing selected" from "no detail pane".
  static const noSelection = Key('AppFrame.noSelection');

  /// Dismisses a two-pane detail. Distinct from a back button: it clears the
  /// selection rather than popping a route.
  static const closeDetail = Key('AppFrame.closeDetail');
}
