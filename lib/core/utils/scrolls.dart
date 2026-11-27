import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

class Scrolls {
  final _historyScrollController = ScrollController();

  // History's calendar (#609) scrolls its months by itself: a controller of
  // its own, so the two views never share one while they swap
  final _historyCalendarScrollController = ScrollController();
  final _historyMonthController = PageController(keepPage: false);
  final _exercisesScrollController = ScrollController();
  final _profileScrollController = ScrollController();
  final _workoutScrollController = ScrollController();
  final _editWorkoutScrollController = ScrollController();

  ScrollController get historyScrollController => _historyScrollController;

  ScrollController get historyCalendarScrollController => _historyCalendarScrollController;

  /// History's calendar a month at a time (#739): page 0 is the current month.
  PageController get historyMonthController => _historyMonthController;

  ScrollController get exercisesScrollController => _exercisesScrollController;

  ScrollController get profileScrollController => _profileScrollController;

  ScrollController get workoutScrollController => _workoutScrollController;

  ScrollController get editWorkoutScrollController => _editWorkoutScrollController;

  static Scrolls of(BuildContext context) {
    return Provider.of<Scrolls>(context, listen: false);
  }

  // `hasContentDimensions` as well as clients: a scrollable built under a
  // pushed route and never shown is attached but not laid out, and its extents
  // are null until it is — a navbar re-tap that pops back to it asks in the
  // same frame.
  static Future<void> _scrollToTop(ScrollController controller) async {
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.animateTo(
        controller.position.minScrollExtent,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeIn,
      );
    }
  }

  static Future<void> _scrollToBottom(ScrollController controller) async {
    if (controller.hasClients && controller.position.hasContentDimensions) {
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

  /// Whichever view History is on: the list's top, or either calendar's
  /// current month — the reversed months' start.
  Future<void> resetHistoryStack({bool lessMotion = false}) async {
    final months = _historyMonthController;
    // from far back straight to the month before, not through every one between
    if (months.hasClients && months.position.hasContentDimensions && (months.page ?? 0) > 1) months.jumpToPage(1);
    // a month sliding by is for show
    if (lessMotion && months.hasClients) months.jumpToPage(0);
    await Future.wait([
      _scrollToTop(_historyScrollController),
      _scrollToTop(_historyCalendarScrollController),
      _scrollToTop(months),
    ]);
  }
}
