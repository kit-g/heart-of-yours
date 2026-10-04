import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class PreviousExercises with ChangeNotifier implements SignOutStateSentry {
  final _previous = <ExerciseId, List<Map<String, dynamic>>>{};

  final PreviousExerciseService _service;
  String? userId;

  new({required this._service});

  @override
  void onSignOut() {
    _previous.clear();
    userId = null;
  }

  static PreviousExercises of(BuildContext context) {
    return Provider.of<PreviousExercises>(context, listen: false);
  }

  static PreviousExercises watch(BuildContext context) {
    return Provider.of<PreviousExercises>(context, listen: true);
  }

  Future<void> init() async {
    if (userId case String id) {
      final previous = await _service.getPreviousSets(id);
      _previous
        ..clear()
        ..addAll(previous);
      notifyListeners();
    }
  }

  Map<String, dynamic>? at(ExerciseId exerciseId, int index) {
    try {
      return _previous[exerciseId]?[index];
    } on RangeError {
      return null;
    }
  }

  /// Last time's counterpart of [exercise]'s set at [index], matched within
  /// its kind (#236): the second warm-up against last session's second
  /// warm-up, the first working set against its first working one. Drop and
  /// failure sets are working sets. Matching by position alone would line a
  /// warm-up up against a working set as soon as their counts differ.
  Map<String, dynamic>? matching(WorkoutExercise exercise, int index) {
    bool isWarmup(SetType type) => type == .warmup;

    final warmup = isWarmup(exercise.elementAt(index).setType);
    final ordinal = exercise.take(index).where((each) => isWarmup(each.setType) == warmup).length;
    return _previous[exercise.exercise.id]
        ?.where((row) => isWarmup(SetType.lenient(row['set_type'] as String?)) == warmup)
        .elementAtOrNull(ordinal);
  }

  Map<String, dynamic>? last(ExerciseId exerciseId) {
    return _previous[exerciseId]?.lastOrNull;
  }

  /// When [exerciseId] was last done: the start of the newest session with a
  /// completed set of it. Null for one never done. Search ranks by it (#135).
  DateTime? lastDone(ExerciseId exerciseId) {
    return switch (_previous[exerciseId]?.firstOrNull?['workout_start']) {
      String start => DateTime.tryParse(start),
      _ => null,
    };
  }
}
