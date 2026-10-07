import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/shortcuts.dart';
import 'package:heart/core/utils/templates.dart';
import 'package:heart/presentation/navigation/system_shortcuts.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The platform's layer, remembering every list it was told.
class _Recorder implements SystemShortcuts {
  final told = <List<ShortcutTemplate>>[];

  @override
  Future<void> setTemplates(Iterable<ShortcutTemplate> templates) async {
    told.add(templates.toList());
  }
}

void main() {
  late Preferences preferences;
  late Templates templates;
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late _Recorder recorder;

  Template template({required String id, required String name, int order = 0}) {
    return Template.fromWorkout(id, Workout(name: name), order);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    // wired as app.dart wires it; no user, so only the samples are read
    templates = Templates(
      service: db,
      remoteService: api,
      configService: cdn,
      folderService: LocalTemplateFolders(db),
      remoteFolderService: api,
      filingService: RemoteTemplateFiling(api),
    );
    recorder = _Recorder();
  });

  tearDown(() {
    templates.dispose();
    preferences.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Templates>.value(value: templates),
        ],
        child: MaterialApp(
          builder: (context, child) => SystemShortcutsPresenter(shortcuts: recorder, child: child!),
          home: const Text('Any route'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('publishes the user\'s templates, then the samples, as they land', (tester) async {
    when(db.getTemplates(null)).thenAnswer((_) async => [template(id: 's1', name: 'Full Body')]);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    // nothing yet: told so, once
    expect(recorder.told, [<ShortcutTemplate>[]]);

    await templates.init();
    await tester.pump();

    expect(recorder.told.last, [const ShortcutTemplate(id: 's1', name: 'Full Body')]);
  });

  testWidgets('the same list is not told twice', (tester) async {
    when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    await templates.init();
    await tester.pump();
    final before = recorder.told.length;

    // a repaint with nothing new
    preferences.setFeature(.rpe, on: true);
    await tester.pump();

    expect(recorder.told.length, before);
  });

  testWidgets('switched off, the assistant knows no template; on again, it does', (tester) async {
    when(db.getTemplates(null)).thenAnswer((_) async => [template(id: 's1', name: 'Push')]);
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    await templates.init();
    await tester.pump();
    expect(recorder.told.last, isNotEmpty);

    preferences.setFeature(.shortcuts, on: false);
    await tester.pump();
    expect(recorder.told.last, isEmpty);

    preferences.setFeature(.shortcuts, on: true);
    await tester.pump();
    expect(recorder.told.last, [const ShortcutTemplate(id: 's1', name: 'Push')]);
  });

  testWidgets('a template without a name is left out', (tester) async {
    when(db.getTemplates(null)).thenAnswer(
      (_) async => [template(id: 's1', name: ' '), template(id: 's2', name: 'Pull', order: 1)],
    );
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    await pump(tester);
    await templates.init();
    await tester.pump();

    expect(recorder.told.last, [const ShortcutTemplate(id: 's2', name: 'Pull')]);
  });
}
