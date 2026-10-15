import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Reads "last time" as of a moment: each exercise's sets from the last
/// finished session that started before it.
typedef PreviousSetsBefore = Future<Map<ExerciseId, List<Map<String, dynamic>>>> Function(
  String userId,
  DateTime before,
);

/// Reads "last time" within one template (#172): each exercise's sets from the
/// last finished workout started from it, and, with `before`, one that
/// started earlier than that moment.
typedef PreviousSetsInTemplate = Future<Map<ExerciseId, List<Map<String, dynamic>>>> Function(
  String userId,
  String templateId, {
  DateTime? before,
});

class PreviousExercises with ChangeNotifier implements SignOutStateSentry {
  final _previous = <ExerciseId, List<Map<String, dynamic>>>{};

  /// Last time within [_templateId]; empty unless this copy follows one.
  final _inTemplate = <ExerciseId, List<Map<String, dynamic>>>{};

  final PreviousExerciseService _service;
  final PreviousSetsBefore? _readBefore;
  final PreviousSetsInTemplate? _readInTemplate;

  /// Set on a copy made by [before]: the moment "last time" is counted from.
  final DateTime? _asOf;

  /// Set on a copy made by [inTemplate]: the template whose last run comes
  /// first.
  final String? _templateId;
  String? userId;
  bool _disposed = false;

  new({required this._service, this._readBefore, this._readInTemplate}) : _asOf = null, _templateId = null;

  new _scoped(this._service, this._readBefore, this._readInTemplate, this._asOf, this._templateId, this.userId);

  /// A copy that counts "last time" from [start] — for a past workout, whose
  /// own sets would otherwise be its "last time" when it is the newest. Not
  /// yet read: [init] it. Without a dated reader it knows no last time at
  /// all, which is still truer than the workout itself.
  PreviousExercises before(DateTime start) {
    return ._scoped(_service, _readBefore, _readInTemplate, start, _templateId, userId);
  }

  /// A copy whose "last time" is the last run of [templateId] (#172) — a
  /// workout started from a template, or a program's session. An exercise
  /// that template never had falls back to last time anywhere, so the column
  /// is empty only where it always was. Not yet read: [init] it.
  PreviousExercises inTemplate(String templateId) {
    return ._scoped(_service, _readBefore, _readInTemplate, _asOf, templateId, userId);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void onSignOut() {
    _previous.clear();
    _inTemplate.clear();
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
      final inTemplate = switch ((_templateId, _readInTemplate)) {
        (String template, PreviousSetsInTemplate read) => await read(id, template, before: _asOf),
        _ => const <ExerciseId, List<Map<String, dynamic>>>{},
      };
      // a scoped copy can go with its screen before the read lands
      if (_disposed) return;
      _previous
        ..clear()
        ..addAll(previous);
      _inTemplate
        ..clear()
        ..addAll(inTemplate);
      notifyListeners();
    }
  }

  /// [exerciseId]'s last time: in the template this copy follows when it was
  /// done there, otherwise anywhere.
  List<Map<String, dynamic>>? _of(ExerciseId exerciseId) => _inTemplate[exerciseId] ?? _previous[exerciseId];

  Map<String, dynamic>? at(ExerciseId exerciseId, int index) {
    try {
      return _of(exerciseId)?[index];
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
    return _of(exercise.exercise.id)
        ?.where((row) => isWarmup(SetType.lenient(row['set_type'] as String?)) == warmup)
        .elementAtOrNull(ordinal);
  }

  Map<String, dynamic>? last(ExerciseId exerciseId) {
    return _of(exerciseId)?.lastOrNull;
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
