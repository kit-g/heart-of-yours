import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Reads "last time" as of a moment: each exercise's sets from the last
/// finished session that started before it.
typedef PreviousSetsBefore = Future<Map<ExerciseId, List<Map<String, dynamic>>>> Function(
  String userId,
  DateTime before,
);

class PreviousExercises with ChangeNotifier implements SignOutStateSentry {
  final _previous = <ExerciseId, List<Map<String, dynamic>>>{};

  final PreviousExerciseService _service;
  final PreviousSetsBefore? _readBefore;

  /// Set on a copy made by [before]: the moment "last time" is counted from.
  final DateTime? _asOf;
  String? userId;
  bool _disposed = false;

  new({required this._service, this._readBefore}) : _asOf = null;

  new _asOf(this._service, this._readBefore, this._asOf, this.userId);

  /// A copy that counts "last time" from [start] — for a past workout, whose
  /// own sets would otherwise be its "last time" when it is the newest. Not
  /// yet read: [init] it. Without a dated reader it knows no last time at
  /// all, which is still truer than the workout itself.
  PreviousExercises before(DateTime start) => ._asOf(_service, _readBefore, start, userId);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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
      final previous = switch ((_asOf, _readBefore)) {
        (DateTime asOf, PreviousSetsBefore read) => await read(id, asOf),
        (DateTime _, null) => const <ExerciseId, List<Map<String, dynamic>>>{},
        (null, _) => await _service.getPreviousSets(id),
      };
      // a scoped copy can go with its screen before the read lands
      if (_disposed) return;
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
