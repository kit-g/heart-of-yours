import 'package:flutter/material.dart';
import 'package:heart_state/heart_state.dart';

class Scrolls {
  final _historyScrollController = ScrollController();
  final _exercisesScrollController = ScrollController();
  final _profileScrollController = ScrollController();
  final _workoutScrollController = ScrollController();

  ScrollController get historyScrollController => _historyScrollController;

  ScrollController get exercisesScrollController => _exercisesScrollController;

  ScrollController get profileScrollController => _profileScrollController;

  ScrollController get workoutScrollController => _workoutScrollController;

  static Scrolls of(BuildContext context) {
    return Provider.of<Scrolls>(context, listen: false);
  }

  static void scrollToTop(ScrollController controller) {
    if (controller.hasClients) {
      controller.animateTo(
        controller.position.minScrollExtent,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeIn,
      );
    }
  }

  void scrollHistoryToTop() {
    return scrollToTop(_historyScrollController);
  }

  void scrollExercisesToTop() {
    return scrollToTop(_exercisesScrollController);
  }

  void scrollProfileToTop() {
    return scrollToTop(_profileScrollController);
  }

  void scrollWorkoutToTop() {
    return scrollToTop(_workoutScrollController);
  }
}
