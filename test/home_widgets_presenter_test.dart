import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/home_widgets.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/navigation/home_widgets.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The platform's layer, remembering every snapshot it was told.
class _Recorder implements HomeWidgets {
  final told = <TrainingSnapshot?>[];

  @override
  Future<void> setTraining(TrainingSnapshot? snapshot) async {
    told.add(snapshot);
  }
}

void main() {
  late Preferences preferences;
  late Workouts workouts;
  late MockWorkoutService service;
  late MockAccountService accounts;
  late Auth auth;
  late AppTheme theme;
  late _Recorder recorder;

  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  Workout finished(DateTime start) {
    final workout = Workout(name: 'Push')..start = start;
    workout
        .add(bench)
        .add(
          ExerciseSet(bench, weight: 100, reps: 5)..isCompleted = true,
        );
    return workout..finish(start.add(const Duration(hours: 1)));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    service = MockWorkoutService();
    workouts = Workouts(service: service, remoteService: MockRemoteWorkoutService())..userId = 'u1';
    accounts = MockAccountService();
    when(accounts.isAuthenticated).thenReturn(false);
    auth = Auth(
      service: accounts,
      firebase: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
      ),
    );
    theme = AppTheme();
    recorder = _Recorder();
  });

  tearDown(() {
    preferences.dispose();
    auth.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Auth>.value(value: auth),
          ChangeNotifierProvider<AppTheme>.value(value: theme),
        ],
        child: HomeWidgetsPresenter(widgets: recorder, child: const SizedBox.shrink()),
      ),
    );
    await tester.pump();
  }

  testWidgets('waits for the history, then tells the days, the unit and the accent', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workout = finished(today.add(const Duration(hours: 1)));
    when(service.getWorkoutHistory('u1')).thenAnswer((_) async => [workout]);
    await pump(tester);
    expect(recorder.told, isEmpty, reason: 'an empty launch would wipe the widget');

    await workouts.initHistory();
    await tester.pump();

    final snapshot = recorder.told.single!;
    expect(snapshot.days[today], (volume: 500.0, workouts: 1, seconds: 3600, sets: 1, reps: 5));
    expect(snapshot.unit, preferences.weightUnit);
    expect(snapshot.accent, theme.preset.light.accent.toARGB32());
  });

  testWidgets('the same snapshot is not told twice; a new unit is', (tester) async {
    when(service.getWorkoutHistory('u1')).thenAnswer((_) async => <Workout>[]);
    await pump(tester);
    await workouts.initHistory();
    await tester.pump();
    expect(recorder.told, hasLength(1));

    // a repaint with nothing new
    preferences.setFeature(.rpe, on: true);
    await tester.pump();
    expect(recorder.told, hasLength(1));

    final other = switch (preferences.weightUnit) {
      .metric => MeasurementUnit.imperial,
      .imperial => MeasurementUnit.metric,
    };
    preferences.setWeightUnit(other);
    await tester.pump();
    expect(recorder.told.last?.unit, other);
  });
}
