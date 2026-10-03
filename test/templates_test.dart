// The Workout tab's Templates flow: `_TemplatesLayout`, `_TemplateCard` and
// `TemplateEditor` (lib/presentation/routes/workout/{templates,card,
// template_editor}.dart). The first two are private to the `workout.dart`
// library, so — unlike `GalleryPage` or the standalone adjust-times dialog —
// there is no way to pump them directly; every test here drives the real app
// through the router, the same way `workout_start_test.dart` and
// `a11y_test.dart` reach the workout tab.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/appbar_textfield.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  const userId = 'u1';

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  /// A template with one exercise (a card with nothing in it is not a
  /// meaningful fixture — every real template has at least one set).
  ///
  /// Built through `Template.empty`/`add` and then round-tripped through
  /// `toMap`/`fromJson` rather than left as the draft `Template.empty`
  /// produces: `empty` always sets `local: true` (the "never saved" mark),
  /// which made `Templates.saveEditable` call `api.saveTemplate` instead of
  /// `api.editTemplate` for what is meant to be an already-synced template —
  /// exactly what `db.getTemplates`/local mirror reads produce for real.
  Template template({required String id, required int order, String? name, TemplateFolder? folder}) {
    final draft = Template.empty(id: id, order: order, folder: folder);
    draft
      ..name = name
      ..add(bench);
    return Template.fromJson(draft.toMap());
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(pastOnboarding());
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();

    stubStartup(db, api);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});

    // The templates/folders baseline: nothing anywhere, so every test starts
    // from the "without" state described in the ticket and only adds what it
    // needs. Both the local mirror and the samples config are asked for.
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(userId)).thenAnswer((_) async => <Template>[]);
    when(api.getTemplates()).thenAnswer((_) async => null);
    when(db.getTemplateFolders(userId)).thenAnswer((_) async => <TemplateFolder>[]);
    when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => <TemplateFolder>[]);

    when(db.storeTemplateFolders(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.storeTemplateFolder(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.deleteTemplateFolder(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.updateTemplate(any)).thenAnswer((_) async {});
    when(db.deleteTemplate(any)).thenAnswer((_) async {});
    when(db.startTemplate(order: anyNamed('order'), userId: anyNamed('userId'))).thenAnswer(
      (invocation) async => Template.empty(
        id: 'draft-1',
        order: invocation.namedArguments[#order] as int? ?? 0,
      ),
    );

    when(api.saveTemplate(any)).thenAnswer((i) async => i.positionalArguments.single as Template);
    when(api.editTemplate(any)).thenAnswer((i) async => i.positionalArguments.single as Template);
    when(api.deleteTemplate(any)).thenAnswer((_) async => true);
    when(
      api.moveTemplate(any, folderId: anyNamed('folderId')),
    ).thenAnswer((i) async {
      final t = i.positionalArguments.single as Template;
      final folderId = i.namedArguments[#folderId] as String?;
      return t.copyWith(
        folder: folderId == null ? null : TemplateFolder(id: folderId, name: 'Push'),
      );
    });
    when(
      api.createFolder(userId: anyNamed('userId'), folder: anyNamed('folder')),
    ).thenAnswer((i) async => (i.namedArguments[#folder] as TemplateFolder).copyWith(id: 'new-folder'));
    when(
      api.updateFolder(userId: anyNamed('userId'), folderId: anyNamed('folderId'), folder: anyNamed('folder')),
    ).thenAnswer((i) async => i.namedArguments[#folder] as TemplateFolder);
    when(
      api.deleteFolder(userId: anyNamed('userId'), folderId: anyNamed('folderId')),
    ).thenAnswer((_) async {});
  });

  /// Signs in as [userId] and lands on the Workout tab. With no active
  /// workout (`getActiveWorkout` answers null, per `stubStartup`) that tab is
  /// `WorkoutPage` showing `_TemplatesLayout` directly — no extra navigation
  /// needed once there.
  ///
  /// `Templates.init()` is called directly rather than left to the app's own
  /// startup chain: that chain runs inside `Zone.root` (see `_initApp` in
  /// `app.dart`), which a widget test's fake-time zone never pumps, so
  /// anything behind it — `Templates.init()` several turns deep, behind
  /// exercises and workouts init — never resolves no matter how many frames
  /// are pumped. `a11y_test.dart` hits the same wall for `Upsync`/`Backfill`
  /// and works around it the same way: calling the notifier directly.
  Future<void> openWorkoutTab(WidgetTester tester, {bool signedIn = true}) async {
    final firebase = signedIn
        ? MockFirebaseAuth(
            mockUser: MockUser(uid: userId, email: '$userId@test'),
            signedIn: true,
          )
        : MockFirebaseAuth(signedIn: false);
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    if (signedIn) {
      final templates = Templates.of(tester.element(find.byType(MaterialApp)));
      await templates.init();
      // `_initSampleTemplates` (part of `init`) never calls `notifyListeners`
      // itself — on a real launch it always resolves before `_TemplatesLayout`
      // is ever built, so nothing needs telling. Here the tab is already on
      // screen before `init` is called, so without this the freshly-fetched
      // samples/templates/folders sit in the notifier unseen until some other
      // change happens to repaint it.
      templates.notifyListeners();
      await tester.pumpTimes();
    }
  }

  group('empty state', () {
    testWidgets('says so when there are no templates and no folders', (tester) async {
      await openWorkoutTab(tester);

      expect(find.text('No templates yet'), findsOneWidget);
      expect(find.text('Example templates'), findsOneWidget);
    });

    testWidgets('the "no folder" strip stays hidden without any folders', (tester) async {
      await openWorkoutTab(tester);

      expect(find.text('No folder'), findsNothing);
    });
  });

  group('rendering', () {
    testWidgets('lists an unfiled template with its exercise summary', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);

      expect(find.text('No templates yet'), findsNothing);
      expect(find.text('Push Day'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('renders sample templates separately from the user\'s own', (tester) async {
      when(cdn.getSampleTemplates()).thenAnswer((_) async => [template(id: 's1', order: 0, name: 'Sample Day')]);

      await openWorkoutTab(tester);

      expect(find.text('Sample Day'), findsOneWidget);
    });

    testWidgets('groups a filed template under its folder, collapsed and expanded', (tester) async {
      when(
        api.getFolders(userId: anyNamed('userId')),
      ).thenAnswer((_) async => [TemplateFolder(id: 'f1', name: 'Push', order: 0)]);
      when(db.getTemplates(userId)).thenAnswer(
        (_) async => [
          template(
            id: 't1',
            order: 0,
            name: 'Bench Day',
            folder: TemplateFolder(id: 'f1', name: 'Push'),
          ),
        ],
      );

      await openWorkoutTab(tester);

      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.textContaining('Push'), findsOneWidget);
      expect(find.text('Bench Day'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);

      final context = tester.element(find.byType(MaterialApp));
      expect(Preferences.of(context).isFolderCollapsed('f1'), isFalse);

      // tapping the header flips the folder's icon and persists the fold —
      // `ExpansionTile`'s own collapse animation (which is what actually hides
      // the card) is the framework's concern, not `_FolderSection`'s, so this
      // sticks to what the app's own code is responsible for.
      await tester.tap(find.textContaining('Push'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(Preferences.of(context).isFolderCollapsed('f1'), isTrue);
    });
  });

  group('starting a workout from a template', () {
    testWidgets('starts one from a user template and opens the active-workout sheet', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();

      expect(find.text('Start a new workout from this template?'), findsOneWidget);

      await tester.tap(find.text('Start workout'));
      await tester.pumpTimes();

      final saved = verify(db.startWorkout(captureAny, userId)).captured.single as Workout;
      expect(saved.name, 'Push Day');
      expect(saved.single.exercise.name, 'Bench Press');
    });

    testWidgets('starts one from a sample template via the card menu, without offering to edit it', (tester) async {
      when(cdn.getSampleTemplates()).thenAnswer((_) async => [template(id: 's1', order: 0, name: 'Sample Day')]);

      await openWorkoutTab(tester);

      final card = find.ancestor(of: find.text('Sample Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();

      // the sample card's menu is restricted to `.startWorkout` — no edit,
      // move or delete for something that isn't the user's to change
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Start workout'), findsOneWidget);

      await tester.tap(find.text('Start workout'));
      await tester.pumpTimes();

      verify(db.startWorkout(any, userId)).called(1);
    });

    testWidgets('over an active workout, asks first, and deletes that one before starting (#228)', (tester) async {
      // discarding clears the old workout's notifications: no plugin runs
      // under `flutter test` (see workout_detail_utils_test.dart)
      FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => null,
      );
      when(db.deleteWorkout(any)).thenAnswer((_) async {});
      when(api.deleteWorkout(any)).thenAnswer((_) async => true);
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      final workouts = Workouts.of(tester.element(find.byType(MaterialApp)));
      await workouts.startWorkout(source: .blank, name: 'Leg Day');
      final legDay = workouts.activeWorkout!.id;
      await tester.pumpTimes();

      await tester.tap(find.text('Push Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel current workout?'), findsOneWidget);
      await tester.tap(find.text('Yes, cancel that one and start a new workout'));
      await tester.pumpTimes();

      verifyInOrder([
        db.deleteWorkout(legDay),
        db.startWorkout(argThat(isA<Workout>().having((workout) => workout.name, 'name', 'Push Day')), userId),
      ]);
      expect(workouts.activeWorkout?.name, 'Push Day');
    });
  });

  group('editing a template', () {
    testWidgets('opens the editor pre-filled, and saving reaches the database', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);

      final card = find.ancestor(of: find.text('Push Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateEditor), findsOneWidget);
      expect(find.text('Edit Template'), findsOneWidget);
      expect(find.byType(AppBarTextField), findsOneWidget);

      // an existing template already has a name and an exercise, so Save
      // starts enabled — no need to type anything before tapping it
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateEditor), findsNothing);
      verify(db.updateTemplate(any)).called(1);
      verify(api.editTemplate(any)).called(1);
    });

    testWidgets('renaming through the field reaches the saved template', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      final card = find.ancestor(of: find.text('Push Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterTextAndWait(find.byType(AppBarTextField), 'Push Day 2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = verify(db.updateTemplate(captureAny)).captured.single as Template;
      expect(saved.name, 'Push Day 2');
    });

    testWidgets('backing out with unsaved changes offers to discard or stay', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      final card = find.ancestor(of: find.text('Push Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final editorContext = tester.element(find.byType(TemplateEditor));
      Navigator.maybePop(editorContext);
      await tester.pumpAndSettle();

      expect(find.text('Quit editing?'), findsOneWidget);

      // stay: the editor is still up, nothing discarded
      await tester.tap(find.text('Stay here'));
      await tester.pumpAndSettle();
      expect(find.byType(TemplateEditor), findsOneWidget);

      Navigator.maybePop(tester.element(find.byType(TemplateEditor)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quit this page'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateEditor), findsNothing);
      // an already-saved template being edited is discarded, not deleted —
      // only a never-saved draft costs a delete call
      verifyNever(db.deleteTemplate(any));
    });

    testWidgets('a brand-new template can be popped freely with nothing added', (tester) async {
      await openWorkoutTab(tester);

      await tester.tap(find.widgetWithText(PrimaryButton, 'Template'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateEditor), findsOneWidget);
      expect(find.text('New Template'), findsOneWidget);

      Navigator.maybePop(tester.element(find.byType(TemplateEditor)));
      await tester.pumpAndSettle();

      // nothing was ever added, so there is nothing to discard a dialog over
      expect(find.text('Quit editing?'), findsNothing);
      expect(find.byType(TemplateEditor), findsNothing);
    });
  });

  group('deleting a template', () {
    testWidgets('confirming removes the card and reaches the database', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      final card = find.ancestor(of: find.text('Push Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Do you want to delete this workout template?'), findsOneWidget);

      await tester.tap(find.text('Yes, delete this'));
      await tester.pumpAndSettle();

      expect(find.text('Push Day'), findsNothing);
      expect(find.text('Deleted'), findsOneWidget);
      verify(db.deleteTemplate('t1')).called(1);
    });

    testWidgets('cancelling leaves the template in place', (tester) async {
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      final card = find.ancestor(of: find.text('Push Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Push Day'), findsOneWidget);
      verifyNever(db.deleteTemplate(any));
    });
  });

  group('folders', () {
    testWidgets('creating one from the header reaches the server', (tester) async {
      await openWorkoutTab(tester);

      await tester.tap(find.byTooltip('New folder'));
      await tester.pumpAndSettle();
      await tester.enterTextAndWait(find.byType(TextField), 'Legs');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final folder =
          verify(
                api.createFolder(userId: anyNamed('userId'), folder: captureAnyNamed('folder')),
              ).captured.single
              as TemplateFolder;
      expect(folder.name, 'Legs');
    });

    testWidgets('is not offered without an account', (tester) async {
      await openWorkoutTab(tester, signedIn: false);

      expect(find.byTooltip('New folder'), findsNothing);
    });

    testWidgets('moving a template files it, and the move dialog reflects it back', (tester) async {
      when(
        api.getFolders(userId: anyNamed('userId')),
      ).thenAnswer((_) async => [TemplateFolder(id: 'f1', name: 'Push', order: 0)]);
      when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', order: 0, name: 'Push Day')]);

      await openWorkoutTab(tester);
      final card = find.ancestor(of: find.text('Push Day'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_horiz)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to folder'));
      await tester.pumpAndSettle();

      // unfiled, so only the existing folder and "new folder" are on offer —
      // no "no folder" option to unfile something that already has none. The
      // background still says "No folder" over the (now-empty) unfiled grid,
      // so the check is scoped to the dialog itself.
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('No folder')), findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('Push')), findsOneWidget);

      await tester.tap(find.descendant(of: dialog, matching: find.text('Push')));
      await tester.pumpAndSettle();

      verify(api.moveTemplate(any, folderId: 'f1')).called(1);
      expect(find.byType(ExpansionTile), findsOneWidget);
    });

    testWidgets('renaming a folder reaches the server', (tester) async {
      when(
        api.getFolders(userId: anyNamed('userId')),
      ).thenAnswer((_) async => [TemplateFolder(id: 'f1', name: 'Push', order: 0)]);

      await openWorkoutTab(tester);
      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename folder'));
      await tester.pumpAndSettle();

      // pre-filled with the current name
      expect(find.text('Push'), findsWidgets);

      await tester.enterTextAndWait(find.byType(TextField), 'Push v2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final folder =
          verify(
                api.updateFolder(
                  userId: anyNamed('userId'),
                  folderId: anyNamed('folderId'),
                  folder: captureAnyNamed('folder'),
                ),
              ).captured.single
              as TemplateFolder;
      expect(folder.name, 'Push v2');
    });

    testWidgets('deleting a folder keeps its templates, unfiled', (tester) async {
      when(
        api.getFolders(userId: anyNamed('userId')),
      ).thenAnswer((_) async => [TemplateFolder(id: 'f1', name: 'Push', order: 0)]);
      when(db.getTemplates(userId)).thenAnswer(
        (_) async => [
          template(
            id: 't1',
            order: 0,
            name: 'Bench Day',
            folder: TemplateFolder(id: 'f1', name: 'Push'),
          ),
        ],
      );

      await openWorkoutTab(tester);
      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete folder'));
      await tester.pumpAndSettle();

      expect(find.text('The templates inside will be kept'), findsOneWidget);

      await tester.tap(find.text('Yes, delete this'));
      await tester.pumpAndSettle();

      verify(api.deleteFolder(userId: anyNamed('userId'), folderId: 'f1')).called(1);
      expect(find.byType(ExpansionTile), findsNothing);
      // the template itself is still on screen, now unfiled
      expect(find.text('Bench Day'), findsOneWidget);
    });
  });
}
