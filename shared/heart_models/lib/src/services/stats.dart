import '../models/stats.dart';

abstract interface class StatsService {
  Future<WorkoutAggregation> getWorkoutSummary({int? weeksBack});
}
