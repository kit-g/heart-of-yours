import 'package:heart_models/heart_models.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks(
  [
    MockSpec<Exercise>(),
    MockSpec<TimersService>(),
    MockSpec<StatsService>(),
  ],
)
void main() {
  //
}
