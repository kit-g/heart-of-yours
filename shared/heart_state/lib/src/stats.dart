import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

/// [StatsService] plus the reads only the local mirror can answer.
///
/// The same shape [LocalGoalService] uses: the shared interface ships from the
/// API repo, so a query the app needs before that interface catches up is
/// declared here and satisfied by an adapter over the database.
abstract interface class LocalStatsService implements StatsService {
  /// Finished workouts in [d]'s calendar month.
  Future<int> getMonthlyWorkoutCount(DateTime d, {String? userId});

  /// The shared signature takes no user, which counted every account that had
  /// ever signed in on the device. Widened here — an override may add optional
  /// parameters — so both counts are scoped the same way.
  @override
  Future<int> getWeeklyWorkoutCount(DateTime d, {String? userId});
}

class Stats with ChangeNotifier implements SignOutStateSentry {
  final LocalStatsService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  Stats({
    required this.onError,
    required LocalStatsService service,
  }) : _service = service;

  String? userId;

  WorkoutAggregation workouts = WorkoutAggregation.empty();

  @override
  void onSignOut() {
    workouts = WorkoutAggregation.empty();
  }

  static Stats of(BuildContext context) {
    return Provider.of<Stats>(context, listen: false);
  }

  static Stats watch(BuildContext context) {
    return Provider.of<Stats>(context, listen: true);
  }

  Future<void> init() async {
    final local = await _service.getWorkoutSummary(userId: userId);
    if (local.isNotEmpty) {
      workouts = local;
      notifyListeners();
      return;
    }
  }

  Future<int> getWeeklyWorkoutCount(DateTime d) {
    return _service.getWeeklyWorkoutCount(d, userId: userId);
  }

  /// Finished workouts so far in [d]'s calendar month.
  ///
  /// A monthly goal cannot be read off [workouts]: those buckets are weeks, and
  /// a week that straddles the first of the month belongs to neither cleanly.
  Future<int> getMonthlyWorkoutCount(DateTime d) {
    return _service.getMonthlyWorkoutCount(d, userId: userId);
  }
}
