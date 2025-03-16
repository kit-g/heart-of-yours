import 'package:flutter/material.dart';
import 'package:heart_state/heart_state.dart';

class Scrolls {
  final _historyScrollController = ScrollController();
  final _exercisesScrollController = ScrollController();
  final _profileScrollController = ScrollController();
  final _workoutScrollController = ScrollController();
  final _editWorkoutScrollController = ScrollController();
  final _exercisesDraggableController = DraggableScrollableController();
  final _historyDraggableController = DraggableScrollableController();

  ScrollController get historyScrollController => _historyScrollController;

  ScrollController get exercisesScrollController => _exercisesScrollController;

  ScrollController get profileScrollController => _profileScrollController;

  ScrollController get workoutScrollController => _workoutScrollController;

  ScrollController get editWorkoutScrollController => _editWorkoutScrollController;

  DraggableScrollableController get exercisesDraggableController => _exercisesDraggableController;

  DraggableScrollableController get historyDraggableController => _historyDraggableController;

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

  Future<void> scrollProfileToTop() {
    return _scrollToTop(_profileScrollController);
  }

  Future<void> scrollWorkoutToTop() {
    return _scrollToTop(_workoutScrollController);
  }

  Future<void> scrollEditableWorkoutToTop() {
    return _scrollToTop(_editWorkoutScrollController);
  }

  static Future<void> _closeSheet(DraggableScrollableController controller) async {
    if (controller.isAttached) {
      return controller.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
    }
  }

  Future<void> resetExerciseStack() {
    if (_exercisesDraggableController.isAttached && _exercisesDraggableController.isOpen) {
      return _closeSheet(_exercisesDraggableController);
    } else {
      return _scrollToTop(_exercisesScrollController);
    }
  }

  Future<void> resetHistoryStack() {
    if (_historyDraggableController.isAttached && _historyDraggableController.isOpen) {
      return _closeSheet(_historyDraggableController);
    } else {
      return _scrollToTop(_historyScrollController);
    }
  }
}

extension on DraggableScrollableController {
  bool get isOpen {
    try {
      return size > 0;
    } on AssertionError {
      return false;
    }
  }
}
