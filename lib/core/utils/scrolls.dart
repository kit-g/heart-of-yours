import 'package:flutter/material.dart';
import 'package:heart_state/heart_state.dart';

class Scrolls {
  final _historyScrollController = ScrollController();
  final _exercisesScrollController = ScrollController();
  final _profileScrollController = ScrollController();
  final _workoutScrollController = ScrollController();
  final _editWorkoutScrollController = ScrollController();

  ScrollController get historyScrollController => _historyScrollController;

  ScrollController get exercisesScrollController => _exercisesScrollController;

  ScrollController get profileScrollController => _profileScrollController;

  ScrollController get workoutScrollController => _workoutScrollController;

  ScrollController get editWorkoutScrollController => _editWorkoutScrollController;

  static Scrolls of(BuildContext context) {
    return Provider.of<Scrolls>(context, listen: false);
  }

  static Future<void> _scrollToTop(ScrollController controller) async {
    if (controller.hasClients) {
      return controller.animateTo(
        controller.position.minScrollExtent,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeIn,
      );
    }
  }

  static Future<void> _scrollToBottom(ScrollController controller) async {
    if (controller.hasClients) {
      return controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> scrollProfileToTop() {
    return _scrollToTop(_profileScrollController);
  }

  Future<void> scrollProfileToBottom() {
    return _scrollToBottom(_profileScrollController);
  }

  Future<void> scrollWorkoutToTop() {
    return _scrollToTop(_workoutScrollController);
  }

  Future<void> scrollEditableWorkoutToTop() {
    return _scrollToTop(_editWorkoutScrollController);
  }

  Future<void> resetExerciseStack() {
    return _scrollToTop(_exercisesScrollController);
  }

  Future<void> resetHistoryStack() {
    return _scrollToTop(_historyScrollController);
  }
}
