import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/removable_chip.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The picker shows what was done last before any typing, and ranks what a
/// query finds by match first and recency second (#135).
void main() {
  Exercise lift(
    String name,
    String key, {
    String category = 'Barbell',
    String target = 'Chest',
    List<String> patterns = const [],
  }) {
    return Exercise.fromJson({
      'id': 'id-$key',
      'key': key,
      'name': name,
      'category': category,
      'target': target,
      if (patterns.isNotEmpty) 'movement': {'groups': patterns},
    });
  }

  final barbell = lift('Bench Press (Barbell)', 'bench-press-barbell', patterns: ['horizontal_press']);
  final dumbbell = lift(
    'Bench Press (Dumbbell)',
    'bench-press-dumbbell',
    category: 'Dumbbell',
    patterns: ['horizontal_press'],
  );
  // two patterns, so grouped by movement it is under both (#620)
  final incline = lift(
    'Incline Bench Press (Barbell)',
    'incline-bench-press-barbell',
    patterns: ['horizontal_press', 'incline_press'],
  );
  // no pattern at all: Other, grouped by movement
  final squat = lift('Squat (Barbell)', 'squat-barbell', target: 'Legs');

  late Exercises exercises;
  late MockExerciseService service;
  late MockRemoteExerciseService remoteService;
  late PreviousExercises previous;
  late Preferences preferences;
  late TextEditingController search;

  setUp(() async {
    // Programs is on by default and would read its own providers, which this
    // test of a widget without them does not build
    SharedPreferences.setMockInitialValues({'feature-programs': 'off'});
    preferences = Preferences();
    await preferences.init();

    service = MockExerciseService();
    remoteService = MockRemoteExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    final library = MockExerciseLibraryService();
    when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
      (_) async => (
        (exercises: [barbell, dumbbell, incline, squat], glossary: SearchGlossary.empty()),
        (version: 'run-1', locale: 'en', etag: null),
      ),
    );
    final catalog = MockLocalCatalogService();
    when(catalog.getCatalogStamp()).thenAnswer((_) async => null);
    when(
      catalog.storeCatalog(any, stamp: anyNamed('stamp'), glossary: anyNamed('glossary')),
    ).thenAnswer((_) async {});
    exercises = Exercises(
      remoteService: remoteService,
      service: service,
      libraryService: library,
      catalogService: catalog,
      preferenceService: MockRemoteExercisePreferenceService(),
      remote: RemoteAccess(),
    );
    await exercises.init();

    final sets = MockPreviousExerciseService();
    when(sets.getPreviousSets(any)).thenAnswer(
      (_) async => {
        incline.id: [
          {'weight': 60.0, 'reps': 8, 'workout_start': '2026-10-03T08:00:00.000Z'},
        ],
        squat.id: [
          {'weight': 100.0, 'reps': 5, 'workout_start': '2026-09-30T08:00:00.000Z'},
        ],
      },
    );
    // the incline is the chest exercise done most
    previous = PreviousExercises(service: sets, readSessions: (_) async => {incline.id: 2, squat.id: 1})..userId = 'u1';
    await previous.init();

    search = TextEditingController();
  });

  tearDown(() => search.dispose());

  Future<void> pump(WidgetTester tester, {bool showsRecent = true}) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<PreviousExercises>.value(value: previous),
          Provider<Scrolls>.value(value: Scrolls()),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: ExercisePicker(
              exercises: exercises,
              searchController: search,
              focusNode: focus,
              showsRecent: showsRecent,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The exercise names on screen, top to bottom.
  List<String> names(WidgetTester tester) {
    final names = {barbell.name, dumbbell.name, incline.name, squat.name};
    return [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        if (text.data case final String name when names.contains(name)) name,
    ];
  }

  testWidgets('before any typing, the last done sit above the whole library, newest first', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('ALL EXERCISES'), findsOneWidget);
    expect(names(tester), [
      // recent
      incline.name,
      squat.name,
      // all, in the library's order
      barbell.name,
      dumbbell.name,
      incline.name,
      squat.name,
    ]);
  });

  testWidgets('a query ranks by match, then by what was done last, in one list', (tester) async {
    await pump(tester);

    search.text = 'bench';
    await tester.pump();

    expect(find.text('RECENT'), findsNothing);
    // both Bench Press names start with the query; the incline, done
    // yesterday, still comes after them
    expect(names(tester), [barbell.name, dumbbell.name, incline.name]);

    search.text = 'press';
    await tester.pump();

    // every one matches by word alone, so recency decides
    expect(names(tester).first, incline.name);
  });

  testWidgets('the library tab keeps its own order, with nothing recent above it', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, showsRecent: false);

    expect(find.text('RECENT'), findsNothing);
    expect(find.text('ALL EXERCISES'), findsNothing);
    expect(names(tester), [barbell.name, dumbbell.name, incline.name, squat.name]);

    // typing still ranks by what was done last
    search.text = 'press';
    await tester.pump();

    expect(names(tester).first, incline.name);
  });

  testWidgets('a lifter with no history sees the library as before', (tester) async {
    final sets = MockPreviousExerciseService();
    when(sets.getPreviousSets(any)).thenAnswer((_) async => {});
    previous = PreviousExercises(service: sets)..userId = 'u1';
    await previous.init();

    await pump(tester);

    expect(find.text('RECENT'), findsNothing);
    expect(find.text('ALL EXERCISES'), findsNothing);
    expect(names(tester), [barbell.name, dumbbell.name, incline.name, squat.name]);
  });

  testWidgets('with nothing of the lifter\'s own, Target and Category share the row evenly (#488)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);

    expect(find.text('Mine'), findsNothing);
    Rect button(String label) =>
        tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(PrimaryButton)));
    final target = button('Target');
    final category = button('Category');
    // no slot held for the absent chip: the row's insets match on both sides
    expect(390 - category.right, moreOrLessEquals(target.left));
    expect(category.width, moreOrLessEquals(target.width));
  });

  group('grouped (#620)', () {
    /// A group's heading, as a screen reader meets it.
    Finder heading(String id) {
      return find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byWidgetPredicate((widget) => widget is Semantics && (widget.properties.header ?? false)),
      );
    }

    void tall(WidgetTester tester, {double height = 1600}) {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('a grouping opens as a screen of folded headings; one opened shows its own and stays open', (
      tester,
    ) async {
      tall(tester);
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);

      expect(heading('target:chest'), findsOneWidget);
      expect(heading('target:legs'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(names(tester), isEmpty);

      await tester.tap(heading('target:chest'));
      await tester.pump();

      expect(names(tester), [barbell.name, dumbbell.name, incline.name]);
      expect(preferences.openPickerGroups.value, {'target:chest'});

      await tester.tap(heading('target:chest'));
      await tester.pump();
      expect(names(tester), isEmpty);
    });

    testWidgets('by movement, an exercise is under each of its patterns, and one with none under Other, last', (
      tester,
    ) async {
      tall(tester);
      preferences
        ..setPickerGrouping(.movement)
        ..togglePickerGroup('movement:horizontal_press')
        ..togglePickerGroup('movement:incline_press')
        ..togglePickerGroup('movement');
      await pump(tester, showsRecent: false);

      expect(find.text('Other'), findsOneWidget);
      expect(names(tester), [
        // horizontal press, the most common
        barbell.name,
        dumbbell.name,
        incline.name,
        // incline press
        incline.name,
        // other
        squat.name,
      ]);
      expect(
        tester.getTopLeft(heading('movement')).dy,
        greaterThan(tester.getTopLeft(heading('movement:incline_press')).dy),
      );
    });

    testWidgets('searching ignores the grouping: one list, ranked', (tester) async {
      preferences.setPickerGrouping(.target);
      await pump(tester);

      search.text = 'bench';
      await tester.pump();

      expect(heading('target:chest'), findsNothing);
      expect(names(tester), [barbell.name, dumbbell.name, incline.name]);

      search.clear();
      await tester.pump();
      expect(heading('target:chest'), findsOneWidget);
    });

    testWidgets(
      'grouped, the filters are neither shown nor applied, and ungrouping brings them back as they were (#711)',
      (
        tester,
      ) async {
        tall(tester);
        exercises
          ..addFilter(Category.dumbbell)
          ..addFilter(const PatternFilter('horizontal_press'));
        preferences.togglePickerGroup('target:chest');
        await pump(tester, showsRecent: false);
        expect(find.text('Target'), findsOneWidget);
        expect(find.byType(RemovableChip), findsNWidgets(2));
        expect(names(tester), [dumbbell.name]);

        preferences.setPickerGrouping(.target);
        await tester.pumpAndSettle();

        expect(find.text('Target'), findsNothing);
        expect(find.text('Category'), findsNothing);
        expect(find.byTooltip('Movement'), findsNothing);
        expect(find.byType(RemovableChip), findsNothing);
        // every group, every exercise: nothing narrows the grouped list
        expect(heading('target:legs'), findsOneWidget);
        expect(names(tester), [barbell.name, dumbbell.name, incline.name]);
        // kept, not cleared
        expect(exercises.filters, hasLength(2));

        // a search while grouped is not filtered either: the row it would
        // apply is not on screen
        search.text = 'bench';
        await tester.pumpAndSettle();
        expect(names(tester), [barbell.name, dumbbell.name, incline.name]);
        search.clear();

        preferences.setPickerGrouping(.none);
        await tester.pumpAndSettle();

        expect(find.text('Target'), findsOneWidget);
        expect(find.byTooltip('Movement'), findsOneWidget);
        expect(find.byType(RemovableChip), findsNWidgets(2));
        expect(names(tester), [dumbbell.name]);
      },
    );

    testWidgets('grouped, Mine stays, and still narrows the list to the user\'s own (#711)', (tester) async {
      tall(tester);
      final own = Exercise(name: 'Muffin Press', category: .machine, target: .chest, isMine: true);
      when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
      when(remoteService.makeExercise(any)).thenAnswer((_) async => own);
      await exercises.makeExercise(own);
      preferences
        ..setPickerGrouping(.target)
        ..togglePickerGroup('target:chest');
      await pump(tester, showsRecent: false);

      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Target'), findsNothing);

      await tester.tap(find.text('Mine'));
      // the picker's host watches the exercises and builds it again; this
      // harness hands them in, so it pumps the picker anew instead
      await pump(tester, showsRecent: false);
      await tester.pumpAndSettle();

      expect(exercises.showingMine, isTrue);
      expect(find.text(own.name), findsOneWidget);
      expect(names(tester), isEmpty);
    });

    testWidgets('grouped, a library opened showing only one thing shows only that, with its chip to clear it (#711)', (
      tester,
    ) async {
      tall(tester);
      preferences
        ..setPickerGrouping(.target)
        ..togglePickerGroup('target:chest');
      // what the profile's pattern lens and an exercise's About chips do
      exercises.showOnly(Category.dumbbell);
      await pump(tester, showsRecent: false);

      expect(find.byType(RemovableChip), findsOneWidget);
      expect(find.descendant(of: find.byType(RemovableChip), matching: find.text('Dumbbell')), findsOneWidget);
      expect(heading('target:legs'), findsNothing);
      expect(names(tester), [dumbbell.name]);
      // no buttons to add to it: grouping stands in for them
      expect(find.text('Target'), findsNothing);
      expect(find.byTooltip('Movement'), findsNothing);

      // a search while grouped keeps to it too
      search.text = 'bench';
      await tester.pumpAndSettle();
      expect(names(tester), [dumbbell.name]);
      search.clear();
      await tester.pumpAndSettle();

      // cleared from its chip, the grouped library is whole again
      await tester.tap(find.byTooltip('Remove filter'));
      await pump(tester, showsRecent: false);
      await tester.pumpAndSettle();
      expect(exercises.filters, isEmpty);
      expect(find.byType(RemovableChip), findsNothing);
      expect(heading('target:legs'), findsOneWidget);
      expect(names(tester), [barbell.name, dumbbell.name, incline.name]);
    });

    testWidgets('grouped, Mine leaves out a group with nothing of the user\'s own in it', (tester) async {
      tall(tester);
      final own = Exercise(name: 'Muffin Press', category: .machine, target: .chest, isMine: true);
      when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
      when(remoteService.makeExercise(any)).thenAnswer((_) async => own);
      await exercises.makeExercise(own);
      exercises.showingMine = true;
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);

      expect(heading('target:chest'), findsOneWidget);
      expect(heading('target:legs'), findsNothing);
    });

    testWidgets('grouped with nothing of the user\'s own, the filter row is gone, not left empty', (tester) async {
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
      // the first heading sits right under the search field's header
      expect(tester.getTopLeft(heading('target:chest')).dy, 64);
    });

    /// The exercise a heading wears the picture of.
    Exercise? pictured(WidgetTester tester, String id) {
      final badge = find.descendant(of: heading(id), matching: find.byType(ExerciseBadge));
      return switch (badge.evaluate().length) {
        0 => null,
        _ => tester.widget<ExerciseBadge>(badge).exercise,
      };
    }

    testWidgets('every heading wears a picture: the one done most, or else the best-known one (#711)', (
      tester,
    ) async {
      tall(tester);
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);

      // the incline is the chest exercise done most
      expect(pictured(tester, 'target:chest'), incline);
      expect(pictured(tester, 'target:legs'), squat);

      // a lifter with no history: the barbell bench, a staple, over the rest
      final sets = MockPreviousExerciseService();
      when(sets.getPreviousSets(any)).thenAnswer((_) async => {});
      previous = PreviousExercises(service: sets, readSessions: (_) async => {})..userId = 'u1';
      await previous.init();
      await pump(tester, showsRecent: false);

      expect(pictured(tester, 'target:chest'), barbell);
    });

    testWidgets('an open heading is tinted apart from the rows under it, a folded one is not (#711)', (tester) async {
      tall(tester);
      preferences
        ..setPickerGrouping(.target)
        ..togglePickerGroup('target:chest');
      await pump(tester, showsRecent: false);

      Color fill() {
        final header = find.ancestor(of: heading('target:chest'), matching: find.byType(Container)).first;
        return (tester.widget<Container>(header).decoration! as BoxDecoration).color!;
      }

      final surface = Theme.of(tester.element(heading('target:chest'))).colorScheme.surface;
      expect(fill(), isNot(surface));
      // opaque: rows scroll under a pinned heading
      expect(fill().a, 1);

      // folded, it keeps the plain fill: a screen of tinted headings ran
      // together into one slab
      await tester.tap(heading('target:chest'));
      await tester.pump();
      expect(fill(), surface);
    });

    testWidgets('a search out of a grouped list fades in too: it is a change of layout, not of the grouping chosen', (
      tester,
    ) async {
      tall(tester);
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);
      double opacity() => tester.widget<SliverFadeTransition>(find.byType(SliverFadeTransition)).opacity.value;

      search.text = 'bench';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), lessThan(1));
      await tester.pumpAndSettle();

      // more typing is the same layout: nothing fades
      search.text = 'bench press';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), 1);
    });

    for (final (name, features) in [
      ('Reduce Motion', const FakeAccessibilityFeatures(reduceMotion: true)),
      ('Remove animations', const FakeAccessibilityFeatures(disableAnimations: true)),
    ]) {
      testWidgets('switching the grouping fades the list in; with $name it switches at once (#711)', (tester) async {
        tall(tester);
        await pump(tester, showsRecent: false);

        double opacity() => tester.widget<SliverFadeTransition>(find.byType(SliverFadeTransition)).opacity.value;
        expect(opacity(), 1);

        preferences.setPickerGrouping(.target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacity(), allOf(greaterThan(0), lessThan(1)));
        await tester.pumpAndSettle();
        expect(opacity(), 1);

        // and back
        preferences.setPickerGrouping(.none);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacity(), lessThan(1));
        await tester.pumpAndSettle();

        tester.platformDispatcher.accessibilityFeaturesTestValue = features;
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pump();

        preferences.setPickerGrouping(.movement);
        await tester.pump();
        expect(opacity(), 1);
        expect(heading('movement:horizontal_press'), findsOneWidget);
      });
    }

    testWidgets('Recent stays on top, ungrouped, over the headings', (tester) async {
      tall(tester);
      preferences.setPickerGrouping(.category);
      await pump(tester);

      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('ALL EXERCISES'), findsOneWidget);
      expect(names(tester), [incline.name, squat.name]);
      expect(
        tester.getTopLeft(find.text('ALL EXERCISES')).dy,
        lessThan(tester.getTopLeft(heading('category:dumbbell')).dy),
      );
      expect(heading('category:barbell'), findsOneWidget);
    });

    testWidgets('with none, nothing is grouped', (tester) async {
      tall(tester);
      preferences.togglePickerGroup('target:chest');
      await pump(tester, showsRecent: false);

      expect(heading('target:chest'), findsNothing);
      expect(names(tester), [barbell.name, dumbbell.name, incline.name, squat.name]);
    });

    testWidgets('a heading is announced as a heading, with its state and what a tap does', (tester) async {
      tall(tester);
      final semantics = tester.ensureSemantics();
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);

      expect(
        tester.getSemantics(heading('target:chest')),
        isSemantics(
          label: 'Chest, 3 exercises',
          value: 'Collapsed',
          isHeader: true,
          isButton: true,
          hasTapAction: true,
          onTapHint: 'Show exercises',
        ),
      );

      await tester.tap(heading('target:chest'));
      await tester.pump();

      expect(
        tester.getSemantics(heading('target:chest')),
        isSemantics(label: 'Chest, 3 exercises', value: 'Expanded', isHeader: true, onTapHint: 'Hide exercises'),
      );
      semantics.dispose();
    });

    testWidgets('a heading stays pinned while its exercises scroll under it', (tester) async {
      // short enough to scroll: grouped, the filter row is gone (#711)
      tall(tester, height: 280);
      preferences
        ..setPickerGrouping(.target)
        ..togglePickerGroup('target:chest');
      await pump(tester, showsRecent: false);

      final top = tester.getTopLeft(heading('target:chest')).dy;
      final first = tester.getTopLeft(find.text(barbell.name)).dy;

      await tester.drag(find.byKey(AppKeys.exercisePicker), const Offset(0, -60));
      await tester.pump();

      expect(tester.getTopLeft(find.text(barbell.name)).dy, lessThan(first));
      expect(tester.getTopLeft(heading('target:chest')).dy, top);
    });

    testWidgets('a grouping chosen elsewhere is the one this picker shows', (tester) async {
      // no control of its own: the Exercises tab's options set it for all
      await pump(tester);
      expect(heading('movement:horizontal_press'), findsNothing);

      preferences.setPickerGrouping(.movement);
      await tester.pump();

      expect(heading('movement:horizontal_press'), findsOneWidget);
    });

    testWidgets('folding a group from its pinned heading brings the list back to the group\'s start', (tester) async {
      // Legs open too, so the list still scrolls once Chest is folded
      tall(tester, height: 220);
      preferences
        ..setPickerGrouping(.target)
        ..togglePickerGroup('target:chest')
        ..togglePickerGroup('target:legs');
      await pump(tester, showsRecent: false);

      final top = tester.getTopLeft(heading('target:chest')).dy;
      await tester.drag(find.byKey(AppKeys.exercisePicker), const Offset(0, -60));
      await tester.pump();
      expect(tester.getTopLeft(heading('target:chest')).dy, top);

      await tester.tap(heading('target:chest'));
      await tester.pump();

      // the folded heading where it was, and the next group straight under it
      final chest = tester.getRect(heading('target:chest'));
      expect(chest.top, top);
      expect(tester.getTopLeft(heading('target:legs')).dy, chest.bottom);
    });

    testWidgets('a heading grows with the text, rather than clipping it', (tester) async {
      tall(tester);
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);
      final regular = tester.getSize(heading('target:chest')).height;
      // the picture's height, with a row's padding around it
      expect(regular, 56);

      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();

      final large = tester.getSize(heading('target:chest')).height;
      final line = tester.getSize(find.text('Chest')).height;
      expect(large, greaterThan(regular));
      expect(large, greaterThanOrEqualTo(line));
    });

    testWidgets('a fold rebuilds the list, not what else watches the preferences', (tester) async {
      tall(tester);
      preferences.setPickerGrouping(.target);
      await pump(tester, showsRecent: false);
      var notified = 0;
      preferences.addListener(() => notified++);

      await tester.tap(heading('target:chest'));
      await tester.pump();

      expect(names(tester), [barbell.name, dumbbell.name, incline.name]);
      expect(notified, 0);
    });
  });
}
