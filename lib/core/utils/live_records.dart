import 'package:heart/core/utils/records.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What the active workout's sets are measured against while they are ticked
/// (#160): each exercise's records over every other workout, read once, when
/// the exercise comes into the workout. Ticking a set then folds in memory
/// ([liveRecordMarks]) and never asks the database.
///
/// Also where, in this session, the one offer of the feature sits: under the
/// set that would have been a record. Session state, like the offer itself
/// (`docs/opt-in.md`): a new launch has no anchor, and by then the offer it
/// left unanswered reads as no.
class LiveRecords with ChangeNotifier {
  final Future<Map?> Function(String userId, Exercise exercise, String workoutId) _without;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({required this._without, this.onError});

  static LiveRecords of(BuildContext context) => Provider.of<LiveRecords>(context, listen: false);

  static LiveRecords watch(BuildContext context) => Provider.of<LiveRecords>(context, listen: true);

  /// The workout [_prior] is for: another one starts the cache over.
  String? _workoutId;
  final _asked = <ExerciseId>{};
  final _prior = <ExerciseId, Map?>{};

  /// Each exercise's records apart from the active workout, by exercise:
  /// null for one nothing else holds. An exercise still being read is absent.
  Map<ExerciseId, Map?> get prior => Map.unmodifiable(_prior);

  /// Reads what [workout]'s exercises have not been read for yet. Idempotent
  /// and silent until a read lands, so a build may call it.
  void prime(String userId, Workout workout) {
    if (workout.id != _workoutId) {
      _workoutId = workout.id;
      _asked.clear();
      _prior.clear();
      _offeredUnder = null;
      _offeredForGoal = false;
    }
    for (final exercise in workout.map((entry) => entry.exercise)) {
      if (!_asked.add(exercise.id)) continue;
      _without(userId, exercise, workout.id).then(
        (records) {
          if (_workoutId != workout.id) return;
          _prior[exercise.id] = records;
          notifyListeners();
        },
        onError: (error, stacktrace) {
          // asked again by the next build, rather than never
          _asked.remove(exercise.id);
          onError?.call(error, stacktrace: stacktrace);
        },
      );
    }
  }

  String? _offeredUnder;
  bool _offeredForGoal = false;

  /// The set the feature's offer sits under, in this session.
  String? get offeredUnder => _offeredUnder;

  /// Whether that set reached a goal (#625) rather than beat a best: the
  /// offer says which.
  bool get offeredForGoal => _offeredForGoal;

  void offerUnder(String setId, {bool forGoal = false}) {
    if (_offeredUnder == setId && _offeredForGoal == forGoal) return;
    _offeredUnder = setId;
    _offeredForGoal = forGoal;
    notifyListeners();
  }
}
