import 'package:flutter/foundation.dart';

abstract final class AppKeys {
  const new _();

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

  /// One goal's row on the goals card. Keyed per goal because the card shows
  /// several and they are otherwise indistinguishable to a finder.
  static Key goalRow(String? goalId) => Key('Goals.row.$goalId');

  /// Dismisses the goal detail surface.
  static const closeGoalDetail = Key('Goals.detail.close');

  /// Appends a rung to a goal's ladder.
  static const addRung = Key('Goals.ladder.add');

  /// Sets or changes a rung's deadline.
  static const rungDueDate = Key('Goals.rung.dueDate');

  /// One rung of a goal's ladder. Keyed per rung so a finder can tell them
  /// apart — swiping one away is how a rung is removed.
  static Key ladderRung(String? stageId) => Key('Goals.ladder.rung.$stageId');

  /// Stands in for the add-goal button once the server would refuse another.
  static const goalsAtCapacity = Key('Goals.atCapacity');

  /// Turns the goals card over to the goals already achieved.
  static const goalsViewAchieved = Key('Goals.viewAchieved');

  /// Turns it back to the goals still being worked on.
  static const goalsViewActive = Key('Goals.viewActive');
}
