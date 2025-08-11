import 'package:heart_models/heart_models.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks(
  [
    MockSpec<Exercise>(),
    MockSpec<TimersService>(),
    MockSpec<AccountService>(),
    MockSpec<StatsService>(),
    MockSpec<TemplateService>(),
    MockSpec<Template>(),
    MockSpec<Workout>(),
    MockSpec<RemoteTemplateService>(),
    MockSpec<RemoteConfigService>(),
    MockSpec<WorkoutService>(),
    MockSpec<RemoteWorkoutService>(),
    MockSpec<RemoteExerciseService>(),
    MockSpec<ExerciseService>(),
  ],
)
void main() {
  //
}
