import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Stats with ChangeNotifier implements SignOutStateSentry {
  final StatsService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  Stats({
    required this.onError,
    required StatsService service,
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
    final local = await _service.getWorkoutSummary();
    if (local.isNotEmpty) {
      workouts = local;
      notifyListeners();
      return;
    }
  }

  Future<int> getWeeklyWorkoutCount(DateTime d) {
    return _service.getWeeklyWorkoutCount(d);
  }
}
