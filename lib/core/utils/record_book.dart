import 'package:heart/core/utils/records.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:heart_state/heart_state.dart';

/// The records a past workout set, as of that workout: what its card in
/// History counts and its page marks beside the sets. As of it, so a record
/// day stays one after a later session beats it. Read on demand from the
/// local store, once per workout per session.
class RecordBook {
  final Future<Map?> Function(String userId, Exercise exercise, String workoutId) _asOf;
  final _read = Expando<Future<List<AchievedRecord>>>();

  new({required this._asOf});

  /// Null where none is provided: a test of a page that never shows records.
  static RecordBook? maybeOf(BuildContext context) {
    try {
      return Provider.of<RecordBook>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Every record [workout] set, firsts included.
  Future<List<AchievedRecord>> achievedBy(Workout workout, {required String userId}) {
    return _read[workout] ??= recordsSetBy(
      workout.id,
      workout,
      lookup: (exercise) => _asOf(userId, exercise, workout.id),
    );
  }

  /// The records [workout] set that beat an earlier value, on their sets.
  Future<RecordMarks> marksOf(Workout workout, {required String userId}) async {
    return recordMarks(workout, await achievedBy(workout, userId: userId));
  }
}
