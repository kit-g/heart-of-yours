import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:mockito/annotations.dart';
import 'package:heart_models/heart_models.dart';

@GenerateNiceMocks(
  [
    MockSpec<AccountService>(),
    MockSpec<ExerciseService>(),
    MockSpec<RemoteExerciseService>(),
    MockSpec<WorkoutService>(),
    MockSpec<RemoteWorkoutService>(),
    MockSpec<TemplateService>(),
    MockSpec<RemoteTemplateService>(),
    MockSpec<RemoteConfigService>(),
    MockSpec<StatsService>(),
    MockSpec<TimersService>(),
    MockSpec<PreviousExerciseService>(),
    MockSpec<Exercise>(),
    MockSpec<ExerciseSet>(),
    MockSpec<WorkoutExercise>(),
    MockSpec<Workout>(),
    MockSpec<Template>(),
    MockSpec<WorkoutAggregation>(),
    MockSpec<WeekSummary>(),
    MockSpec<Api>(),
    MockSpec<ConfigApi>(),
    MockSpec<LocalDatabase>(),
    MockSpec<ChartPreference>(),
    MockSpec<ChartPreferenceService>(),
  ],
)
void main() {
  //
}
