import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'lens.dart';
import 'weeks.dart';

/// Completed sets of one exercise in one finished workout, with when the
/// workout started and what the exercise trains — the muscle map's unit of
/// data (#136).
typedef MuscleSets = ({DateTime start, MuscleTagging muscles, int sets});

/// [StatsService] plus the reads only the local mirror can answer.
///
/// The same shape [LocalGoalService] uses: the shared interface ships from the
/// API repo, so a query the app needs before that interface catches up is
/// declared here and satisfied by an adapter over the database.
abstract interface class LocalStatsService implements StatsService {
  /// Finished workouts in [d]'s calendar month.
  Future<int> getMonthlyWorkoutCount(DateTime d, {String? userId});

  /// Every finished workout, unbounded — what a "do N workouts" goal counts.
  Future<int> getTotalWorkoutCount({String? userId});

  /// The shared signature takes no user, which counted every account that had
  /// ever signed in on the device. Widened here — an override may add optional
  /// parameters — so both counts are scoped the same way.
  @override
  Future<int> getWeeklyWorkoutCount(DateTime d, {String? userId});

  /// Finished workouts that started in [from, to): the count every period is
  /// built on, with the caller deciding where a week begins (#339).
  Future<int> getWorkoutCountBetween(DateTime from, DateTime to, {String? userId});

  /// Completed sets per exercise per finished workout started in [from, to)
  /// (#136).
  Future<List<MuscleSets>> getMuscleSets(DateTime from, DateTime to, {String? userId});

  /// Completed working sets per exercise per finished workout started in
  /// [from, to), with the workout and what the exercise is (#341).
  Future<List<LensSets>> getLensSets(DateTime from, DateTime to, {String? userId});
}

class Stats with ChangeNotifier implements SignOutStateSentry {
  final LocalStatsService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({
    required this.onError,
    required this._service,
  });

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

  /// Finished workouts in [d]'s week, which starts on [firstWeekday] — the
  /// user's choice, from [Preferences.firstWeekday].
  Future<int> getWeeklyWorkoutCount(DateTime d, {required int firstWeekday}) {
    final (from, to) = weekRange(d, firstWeekday: firstWeekday);
    return _service.getWorkoutCountBetween(from, to, userId: userId);
  }

  /// Finished workouts so far in [d]'s calendar month.
  ///
  /// A monthly goal cannot be read off [workouts]: those buckets are weeks, and
  /// a week that straddles the first of the month belongs to neither cleanly.
  Future<int> getMonthlyWorkoutCount(DateTime d) {
    return _service.getMonthlyWorkoutCount(d, userId: userId);
  }

  /// Every finished workout this device knows about.
  Future<int> getTotalWorkoutCount() {
    return _service.getTotalWorkoutCount(userId: userId);
  }

  /// What the muscle map (#136) is counted from: completed sets per exercise
  /// per workout in [from, to), with each exercise's tagging. Read on demand rather than
  /// held here — nothing is computed or kept while the feature is off.
  Future<List<MuscleSets>> getMuscleSets(DateTime from, DateTime to) {
    return _service.getMuscleSets(from, to, userId: userId);
  }

  /// What the pattern lens (#341) is counted from: completed working sets per
  /// exercise per workout in [from, to), with the workout and what the
  /// exercise is. Read on demand, like [getMuscleSets]: nothing is kept here.
  Future<List<LensSets>> getLensSets(DateTime from, DateTime to) {
    return _service.getLensSets(from, to, userId: userId);
  }
}
