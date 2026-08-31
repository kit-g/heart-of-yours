import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/templates.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'mocks.mocks.dart';
import 'test_utils.dart';

void main() {
  group('Templates (unit)', () {
    final local = MockTemplateService();
    final remote = MockRemoteTemplateService();
    final config = MockRemoteConfigService();
    final localFolders = MockLocalTemplateFolderService();
    final remoteFolders = MockApiTemplateFolderService();
    final filing = MockRemoteTemplateFilingService();
    late Templates templates;
    late ListenerProbe probe;

    setUp(() {
      templates = Templates(
        remoteService: remote,
        service: local,
        configService: config,
        folderService: localFolders,
        remoteFolderService: remoteFolders,
        filingService: filing,
      );
      probe = ListenerProbe()..attach(templates);

      // most tests are not about folders; an empty world keeps them quiet
      when(localFolders.getFolders(any)).thenAnswer((_) async => []);
      when(remoteFolders.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => []);
    });

    group('init', () {
      test('populates samples from local when available (no notify)', () async {
        final sampleLocal = [tmpl(id: 's1', order: 0, name: 'Sample')];
        when(local.getTemplates(null)).thenAnswer((_) async => sampleLocal);

        await templates.init();

        expect(templates.samples.length, sampleLocal.length);
        expect(templates.samples.first.id, sampleLocal.first.id);
        // verified by behavior; specific argument matching for function type can be brittle
        expect(probe.notifications, 0); // samples do not trigger notify
      });

      test('a locale change re-fetches the samples and notifies', () async {
        // sample names are picked per language at fetch time; a mid-session
        // language change must swap the batch in place, visibly
        when(local.getTemplates(null)).thenAnswer((_) async => <Template>[]);
        when(config.getSampleTemplates()).thenAnswer((_) async => [tmpl(id: 's1', order: 0, name: 'Push Day')]);

        await templates.init();
        // the samples init is deliberately un-awaited; let it land
        await pumpEventQueue();
        expect(templates.samples.single.name, 'Push Day');
        final before = probe.notifications;

        when(config.getSampleTemplates()).thenAnswer((_) async => [tmpl(id: 's1', order: 0, name: 'Día de empuje')]);

        await templates.onLocaleChanged();

        expect(templates.samples.single.name, 'Día de empuje');
        expect(probe.notifications, before + 1);
      });

      test('a failing samples fetch is routed to onError and costs only the samples', () async {
        // static content ships on its own schedule and can lag the models —
        // nobody awaits the samples init, so an escaping error would surface
        // as an unhandled async exception on every launch
        Object? reported;
        templates = Templates(
          remoteService: remote,
          service: local,
          configService: config,
          folderService: localFolders,
          remoteFolderService: remoteFolders,
          filingService: filing,
          onError: (e, {stacktrace}) => reported = e,
        )..userId = 'u1';

        final localTemplates = [tmpl(id: 't1', order: 1, name: 'L1')];
        when(local.getTemplates(null)).thenAnswer((_) async => <Template>[]);
        when(config.getSampleTemplates()).thenThrow(ArgumentError('an exercise payload must carry its id'));
        when(local.getTemplates('u1')).thenAnswer((_) async => localTemplates);

        await templates.init();
        await pumpEventQueue();

        expect(reported, isA<ArgumentError>());
        expect(templates.samples, isEmpty);
        // the user's own templates are untouched by the samples failing
        expect(templates.toList(), localTemplates);
      });

      test('with userId: loads local templates and notifies when non-empty', () async {
        templates.userId = 'u1';
        final localTemplates = [tmpl(id: 't1', order: 1, name: 'L1')];
        when(local.getTemplates(null)).thenAnswer((_) async => <Template>[]); // samples path irrelevant
        when(config.getSampleTemplates()).thenAnswer((_) async => []);
        when(local.getTemplates('u1')).thenAnswer((_) async => localTemplates);

        await templates.init();

        // iterator should contain localTemplates
        expect(templates.toList(), localTemplates);
        expect(probe.notifications, 1);
      });

      test('with userId: falls back to remote templates, notifies and stores locally', () async {
        templates.userId = 'u1';
        when(local.getTemplates(null)).thenAnswer((_) async => []);
        when(config.getSampleTemplates()).thenAnswer((_) async => []);
        when(local.getTemplates('u1')).thenAnswer((_) async => []);
        final remoteTemplates = [tmpl(id: 'rt1', order: 1, name: 'R1')];
        when(remote.getTemplates()).thenAnswer((_) async => remoteTemplates);

        await templates.init();

        expect(templates.toList(), remoteTemplates);
        expect(probe.notifications, 1);
        verify(local.storeTemplates(remoteTemplates, userId: 'u1')).called(1);
      });

      test('with userId: nothing to load -> no notify', () async {
        templates.userId = 'u1';
        when(local.getTemplates(null)).thenAnswer((_) async => []);
        when(config.getSampleTemplates()).thenAnswer((_) async => []);
        when(local.getTemplates('u1')).thenAnswer((_) async => []);
        when(remote.getTemplates()).thenAnswer((_) async => []);

        await templates.init();
        expect(templates.length, 0);
        expect(probe.notifications, 0);
      });
    });

    group('editing and CRUD', () {
      test('add starts a new template with correct order and adds exercise, notifies', () async {
        templates.userId = 'u1';
        when(local.startTemplate(order: 1, userId: 'u1')).thenAnswer((_) async => Template.empty(id: 'new', order: 1));

        await templates.add(ex('Push Up'));

        expect(templates.editable, isNotNull);
        expect(templates.editable!.length, 1);
        verify(local.startTemplate(order: 1, userId: 'u1')).called(1);
        expect(probe.notifications, 1);
      });

      test('remove does not notify (by design)', () async {
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        final exercise = templates.editable!.first;
        templates.remove(exercise);
        expect(templates.editable!.length, 0);
        expect(probe.notifications, 0);
      });

      test('addSet and removeSet notify and mutate sets', () async {
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        await templates.add(ex('Push Up'));
        final exercise = templates.editable!.first;
        probe.notifications = 0;

        templates.addSet(exercise);
        expect(exercise.length, 2);
        expect(probe.notifications, 1);

        final set = exercise.last;
        templates.removeSet(exercise, set);
        expect(exercise.length, 1);
        expect(probe.notifications, 2);
      });

      test('removeExercise notifies', () async {
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        final exercise = templates.editable!.first;
        templates.removeExercise(exercise);
        expect(templates.editable!.length, 0);
        expect(probe.notifications, 1);
      });

      test('swap and append notify', () async {
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        await templates.add(ex('Push Up'));
        await templates.add(ex('Squat'));
        final e1 = templates.editable!.first;
        final e2 = templates.editable!.last;
        probe.notifications = 0;

        templates.swap(e2, e1);
        expect(templates.editable!.first, e2);
        expect(probe.notifications, 1);

        templates.append(e1);
        expect(templates.editable!.last, e1);
        expect(probe.notifications, 2);
      });

      test('saveEditable adds to collection, persists local and remote, clears editable, and notifies', () async {
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        when(remote.saveTemplate(any)).thenAnswer((inv) async => inv.positionalArguments.first as Template);
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        await templates.saveEditable();

        expect(templates.editable, isNull);
        expect(templates.length, 1);
        verify(local.updateTemplate(any)).called(1);
        verify(remote.saveTemplate(any)).called(1);
        expect(probe.notifications, 1);
      });

      test('discardEditable deletes the draft row a discarded editor left behind', () async {
        // the row exists from the first dropped exercise, so walking away
        // without saving used to leave a nameless card in the list forever
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'draft-1', order: 1));
        when(local.deleteTemplate('draft-1')).thenAnswer((_) async {});
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        await templates.discardEditable();

        expect(templates.editable, isNull);
        expect(templates.length, 0);
        expect(probe.notifications, 1);
        verify(local.deleteTemplate('draft-1')).called(1);
      });

      test('discardEditable keeps a saved template it was only editing', () async {
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'kept-1', order: 1));
        when(remote.saveTemplate(any)).thenAnswer((inv) async => inv.positionalArguments.first as Template);
        await templates.add(ex('Push Up'));
        await templates.saveEditable();

        // quitting an edit throws away the edits, not the template
        templates.editable = templates.first;
        await templates.discardEditable();

        expect(templates.editable, isNull);
        expect(templates.length, 1);
        verifyNever(local.deleteTemplate('kept-1'));
      });

      test('delete removes from collection, notifies, and deletes locally and remotely', () async {
        // Prepare one in collection by saving editable
        when(
          local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        when(remote.saveTemplate(any)).thenAnswer((inv) async => inv.positionalArguments.first as Template);
        await templates.add(ex('Push Up'));
        await templates.saveEditable();
        expect(templates.length, 1);
        probe.notifications = 0;

        final t = templates.first;
        when(local.deleteTemplate(t.id)).thenAnswer((_) async {});
        when(remote.deleteTemplate(t.id)).thenAnswer((_) async => true);

        await templates.delete(t);

        expect(templates.length, 0);
        expect(probe.notifications, 1);
        verify(local.deleteTemplate(t.id)).called(1);
        verify(remote.deleteTemplate(t.id)).called(1);
      });

      test('allowsNewTemplate is false when 6 or more templates exist', () async {
        // Add 6 templates by saving multiple editables
        var orderCounter = 0;
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId'))).thenAnswer((inv) async {
          orderCounter += 1;
          return Template.empty(id: UniqueKey().toString(), order: orderCounter);
        });
        when(remote.saveTemplate(any)).thenAnswer((inv) async => inv.positionalArguments.first as Template);
        for (var i = 0; i < 6; i++) {
          await templates.add(ex('Push Up'));
          await templates.saveEditable();
        }
        expect(templates.length, 6);
        expect(templates.allowsNewTemplate, isFalse);
      });

      test('workoutToTemplate uses startTemplate for raw and creates editable from workout, notifying', () async {
        final workout = Workout(name: 'Morning')..append(WorkoutExercise(starter: ExerciseSet(ex('Push Up'))));
        when(
          local.startTemplate(userId: anyNamed('userId')),
        ).thenAnswer((_) async => Template.empty(id: 'raw-id', order: 3));

        await templates.workoutToTemplate(workout);

        expect(templates.editable, isNotNull);
        expect(templates.editable!.name, 'Morning');
        expect(probe.notifications, 1);
      });
    });

    test('onSignOut clears editable, userId and templates (no notify)', () {
      templates.userId = 'u1';
      // put one into collection
      templates.onSignOut();
      expect(templates.userId, isNull);
      expect(templates.editable, isNull);
      expect(templates.length, 0);
      expect(probe.notifications, 0);
    });

    group('folders', () {
      setUp(() {
        // the mocks are shared across the whole file; these tests verify
        // calls and captures, which stale interactions would pollute
        for (final mock in [local, remote, config, localFolders, remoteFolders, filing]) {
          reset(mock);
        }
        templates.userId = 'u1';
        when(local.getTemplates(null)).thenAnswer((_) async => []);
        when(config.getSampleTemplates()).thenAnswer((_) async => []);
        when(local.getTemplates('u1')).thenAnswer((_) async => []);
        when(remote.getTemplates()).thenAnswer((_) async => []);
        when(localFolders.getFolders(any)).thenAnswer((_) async => []);
        when(remoteFolders.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => []);
      });

      test('init loads the local mirror first, then replaces it with the server\'s list', () async {
        final cached = fldr(id: 'f1', name: 'Cached');
        final fresh = [fldr(id: 'f1', name: 'Renamed'), fldr(id: 'f2', name: 'New', order: 1)];
        when(localFolders.getFolders('u1')).thenAnswer((_) async => [cached]);
        when(remoteFolders.getFolders(userId: 'u1')).thenAnswer((_) async => fresh);

        await templates.init();

        expect(templates.folders.map((f) => f.name), ['Renamed', 'New']);
        // and the confirmed list is what lands in the mirror
        verify(localFolders.storeFolders(argThat(equals(fresh)), 'u1')).called(1);
      });

      test('createFolder is remote-first: the server\'s copy is kept and mirrored', () async {
        final minted = fldr(id: 'server-1', name: 'Push');
        when(remoteFolders.createFolder(userId: 'u1', folder: anyNamed('folder'))).thenAnswer((_) async => minted);

        final created = await templates.createFolder('Push');

        expect(created.id, 'server-1');
        expect(templates.folders, [minted]);
        expect(probe.notifications, 1);
        verify(localFolders.storeFolder(minted, 'u1')).called(1);
      });

      test('createFolder hands the next position to the server', () async {
        when(remoteFolders.getFolders(userId: 'u1')).thenAnswer((_) async => [fldr(id: 'f1', order: 3)]);
        await templates.init();
        when(remoteFolders.createFolder(userId: 'u1', folder: anyNamed('folder'))).thenAnswer(
          (inv) async => inv.namedArguments[#folder] as TemplateFolder,
        );

        await templates.createFolder('Pull');

        final sent =
            verify(
                  remoteFolders.createFolder(userId: 'u1', folder: captureAnyNamed('folder')),
                ).captured.single
                as TemplateFolder;
        expect(sent.order, 4);
      });

      test('a rejected createFolder throws and keeps nothing', () async {
        when(remoteFolders.createFolder(userId: 'u1', folder: anyNamed('folder'))).thenThrow(
          {'code': 'bad_request', 'reason': 'you already have a folder called "Push"'},
        );

        await expectLater(templates.createFolder('Push'), throwsA(isA<Map>()));
        expect(templates.folders, isEmpty);
        verifyNever(localFolders.storeFolder(any, any));
      });

      test('renameFolder refreshes the copy every filed template nests', () async {
        final folder = fldr(id: 'f1', name: 'Push');
        when(remoteFolders.getFolders(userId: 'u1')).thenAnswer((_) async => [folder]);
        when(local.getTemplates('u1')).thenAnswer((_) async => [tmpl(id: 't1', folder: folder)]);
        await templates.init();

        final renamed = folder.copyWith(name: 'Legs');
        when(
          remoteFolders.updateFolder(userId: 'u1', folderId: 'f1', folder: anyNamed('folder')),
        ).thenAnswer((_) async => renamed);

        await templates.renameFolder(folder, 'Legs');

        expect(templates.folders.single.name, 'Legs');
        expect(templates.single.folder?.name, 'Legs');
        verify(localFolders.storeFolder(renamed, 'u1')).called(1);
      });

      test('deleteFolder unfiles its templates, in memory and in the mirror', () async {
        final folder = fldr(id: 'f1');
        when(remoteFolders.getFolders(userId: 'u1')).thenAnswer((_) async => [folder]);
        when(local.getTemplates('u1')).thenAnswer((_) async => [tmpl(id: 't1', folder: folder)]);
        await templates.init();

        when(remoteFolders.deleteFolder(userId: 'u1', folderId: 'f1')).thenAnswer((_) async {});

        await templates.deleteFolder(folder);

        expect(templates.folders, isEmpty);
        expect(templates.single.folder, isNull);
        verify(localFolders.deleteFolder('f1', 'u1')).called(1);
      });

      test('moveToFolder files optimistically and keeps the server\'s copy', () async {
        final folder = fldr(id: 'f1');
        final template = tmpl(id: 't1', name: 'Push day');
        when(localFolders.getFolders('u1')).thenAnswer((_) async => [folder]);
        when(local.getTemplates('u1')).thenAnswer((_) async => [template]);
        await templates.init();

        // the server answers with the template wearing its new folder
        when(filing.moveTemplate(any, folderId: 'f1')).thenAnswer(
          (_) async => tmpl(id: 't1', name: 'Push day', folder: folder),
        );

        await templates.moveToFolder(template, folder);

        expect(templates.single.folderId, 'f1');
        verify(local.storeTemplates(any, userId: 'u1')).called(1);
      });

      test('a rejected move rolls back and reports', () async {
        final folder = fldr(id: 'f1');
        final template = tmpl(id: 't1');
        when(localFolders.getFolders('u1')).thenAnswer((_) async => [folder]);
        when(local.getTemplates('u1')).thenAnswer((_) async => [template]);
        await templates.init();

        when(filing.moveTemplate(any, folderId: 'f1')).thenThrow({'error': 'not found'});

        await templates.moveToFolder(template, folder);

        expect(templates.single.folderId, isNull);
        verifyNever(local.storeTemplates(any, userId: 'u1'));
      });

      test('moving a template to where it already is does nothing', () async {
        final folder = fldr(id: 'f1');
        final template = tmpl(id: 't1', folder: folder);
        when(localFolders.getFolders('u1')).thenAnswer((_) async => [folder]);
        when(local.getTemplates('u1')).thenAnswer((_) async => [template]);
        await templates.init();

        await templates.moveToFolder(template, folder);

        verifyNever(filing.moveTemplate(any, folderId: anyNamed('folderId')));
      });

      test('templatesIn groups by folder, null meaning unfiled', () async {
        final folder = fldr(id: 'f1');
        final filed = tmpl(id: 't1', folder: folder);
        final unfiled = tmpl(id: 't2', order: 1);
        when(localFolders.getFolders('u1')).thenAnswer((_) async => [folder]);
        when(local.getTemplates('u1')).thenAnswer((_) async => [filed, unfiled]);
        await templates.init();

        expect(templates.templatesIn(folder), [filed]);
        expect(templates.templatesIn(null), [unfiled]);
      });

      test('onSignOut clears the folders too', () async {
        when(remoteFolders.getFolders(userId: 'u1')).thenAnswer((_) async => [fldr()]);
        await templates.init();
        expect(templates.folders, isNotEmpty);

        templates.onSignOut();

        expect(templates.folders, isEmpty);
      });
    });
  });

  group('Templates with Provider (widget)', () {
    testWidgets('of(context) returns the same instance as provided', (tester) async {
      final provided = Templates(
        remoteService: MockRemoteTemplateService(),
        service: MockTemplateService(),
        configService: MockRemoteConfigService(),
        folderService: MockLocalTemplateFolderService(),
        remoteFolderService: MockApiTemplateFolderService(),
        filingService: MockRemoteTemplateFilingService(),
      );
      late Templates fromOf;

      await tester.pumpWidget(
        ChangeNotifierProvider<Templates>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              fromOf = Templates.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(fromOf, provided), isTrue);
    });

    testWidgets('watch(context) rebuilds on notifyListeners for save/delete', (tester) async {
      final remote = MockRemoteTemplateService();
      final local = MockTemplateService();
      final provided = Templates(
        remoteService: remote,
        service: local,
        configService: MockRemoteConfigService(),
        folderService: MockLocalTemplateFolderService(),
        remoteFolderService: MockApiTemplateFolderService(),
        filingService: MockRemoteTemplateFilingService(),
      );
      when(
        local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')),
      ).thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
      when(remote.saveTemplate(any)).thenAnswer((inv) async => inv.positionalArguments.first as Template);

      var builds = 0;
      Widget consumer() {
        return Builder(
          builder: (context) {
            // Subscribe
            final len = Templates.watch(context).length;
            builds++;
            return Text('len=$len', textDirection: TextDirection.ltr);
          },
        );
      }

      await tester.pumpWidget(
        ChangeNotifierProvider<Templates>.value(
          value: provided,
          child: consumer(),
        ),
      );

      final initialBuilds = builds;
      expect(initialBuilds, 1);

      // saveEditable notifies
      await provided.add(ex('Push Up'));
      await provided.saveEditable();
      await tester.pump();
      expect(builds, initialBuilds + 1);

      // delete notifies
      final t = provided.first;
      when(local.deleteTemplate(t.id)).thenAnswer((_) async {});
      when(remote.deleteTemplate(t.id)).thenAnswer((_) async => true);
      await provided.delete(t);
      await tester.pump();
      expect(builds, initialBuilds + 2);

      expect(find.byType(Text), findsOneWidget);
    });
  });
}
