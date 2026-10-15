import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/workout/previous_scope.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// "Last time in this template" (#172): what the Previous column reads under
/// [PreviousScope], with the feature on and off.
void main() {
  late Preferences preferences;
  late PreviousExercises previous;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    final service = MockPreviousExerciseService();
    when(service.getPreviousSets(any)).thenAnswer(
      (_) async => {
        'bench': [
          {'set_id': 'anywhere'},
        ],
      },
    );
    previous = PreviousExercises(
      service: service,
      readInTemplate: (user, template, {before}) async => {
        'bench': [
          {'set_id': template},
        ],
      },
    )..userId = 'u1';
    await previous.init();
  });

  tearDown(() {
    previous.dispose();
    preferences.dispose();
  });

  Future<void> pump(WidgetTester tester, {String? templateId}) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<PreviousExercises>.value(value: previous),
        ],
        child: Directionality(
          textDirection: .ltr,
          child: PreviousScope(
            templateId: templateId,
            child: Builder(
              builder: (context) => Text('${PreviousExercises.watch(context).at('bench', 0)?['set_id']}'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('off, a workout from a template reads last time anywhere', (tester) async {
    await pump(tester, templateId: 'heavy');
    await tester.pumpAndSettle();

    expect(find.text('anywhere'), findsOneWidget);
  });

  testWidgets("on, it reads the template's last run", (tester) async {
    preferences.setFeature(.previousInTemplate, on: true);
    await pump(tester, templateId: 'heavy');
    await tester.pumpAndSettle();

    expect(find.text('heavy'), findsOneWidget);
  });

  testWidgets('on, a workout from no template reads last time anywhere', (tester) async {
    preferences.setFeature(.previousInTemplate, on: true);
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('anywhere'), findsOneWidget);
  });

  testWidgets('turning it off mid-workout goes back to last time anywhere', (tester) async {
    preferences.setFeature(.previousInTemplate, on: true);
    await pump(tester, templateId: 'heavy');
    await tester.pumpAndSettle();
    expect(find.text('heavy'), findsOneWidget);

    preferences.setFeature(.previousInTemplate, on: false);
    await tester.pumpAndSettle();

    expect(find.text('anywhere'), findsOneWidget);
  });
}
