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
    late Templates templates;
    late ExerciseLookup lookup;
    late ListenerProbe probe;

    setUp(() {
      lookup = buildLookup({
        'Push Up': ex('Push Up'),
        'Squat': ex('Squat'),
      });
      templates = Templates(
        remoteService: remote,
        service: local,
        configService: config,
        lookForExercise: lookup,
      );
      probe = ListenerProbe()..attach(templates);
    });

    group('init', () {
      test('populates samples from local when available (no notify)', () async {
        final sampleLocal = [tmpl(id: 's1', order: 0, name: 'Sample')];
        when(local.getTemplates(null, lookup)).thenAnswer((_) async => sampleLocal);

        await templates.init();

        expect(templates.samples.length, sampleLocal.length);
        expect(templates.samples.first.id, sampleLocal.first.id);
        // verified by behavior; specific argument matching for function type can be brittle
        expect(probe.notifications, 0); // samples do not trigger notify
      });

      test('with userId: loads local templates and notifies when non-empty', () async {
        templates.userId = 'u1';
        final localTemplates = [tmpl(id: 't1', order: 1, name: 'L1')];
        when(local.getTemplates(null, lookup)).thenAnswer((_) async => <Template>[]); // samples path irrelevant
        when(config.getSampleTemplates(any)).thenAnswer((_) async => []);
        when(local.getTemplates('u1', any)).thenAnswer((_) async => localTemplates);

        await templates.init();

        // iterator should contain localTemplates
        expect(templates.toList(), localTemplates);
        expect(probe.notifications, 1);
      });

      test('with userId: falls back to remote templates, notifies and stores locally', () async {
        templates.userId = 'u1';
        when(local.getTemplates(null, any)).thenAnswer((_) async => []);
        when(config.getSampleTemplates(any)).thenAnswer((_) async => []);
        when(local.getTemplates('u1', any)).thenAnswer((_) async => []);
        final remoteTemplates = [tmpl(id: 'rt1', order: 1, name: 'R1')];
        when(remote.getTemplates(any)).thenAnswer((_) async => remoteTemplates);

        await templates.init();

        expect(templates.toList(), remoteTemplates);
        expect(probe.notifications, 1);
        verify(local.storeTemplates(remoteTemplates, userId: 'u1')).called(1);
      });

      test('with userId: nothing to load -> no notify', () async {
        templates.userId = 'u1';
        when(local.getTemplates(null, any)).thenAnswer((_) async => []);
        when(config.getSampleTemplates(any)).thenAnswer((_) async => []);
        when(local.getTemplates('u1', any)).thenAnswer((_) async => []);
        when(remote.getTemplates(any)).thenAnswer((_) async => []);

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
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        final exercise = templates.editable!.first;
        templates.remove(exercise);
        expect(templates.editable!.length, 0);
        expect(probe.notifications, 0);
      });

      test('addSet and removeSet notify and mutate sets', () async {
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
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
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        final exercise = templates.editable!.first;
        templates.removeExercise(exercise);
        expect(templates.editable!.length, 0);
        expect(probe.notifications, 1);
      });

      test('swap and append notify', () async {
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
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
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        when(remote.saveTemplate(any)).thenAnswer((_) async => true);
        await templates.add(ex('Push Up'));
        probe.notifications = 0;

        await templates.saveEditable();

        expect(templates.editable, isNull);
        expect(templates.length, 1);
        verify(local.updateTemplate(any)).called(1);
        verify(remote.saveTemplate(any)).called(1);
        expect(probe.notifications, 1);
      });

      test('delete removes from collection, notifies, and deletes locally and remotely', () async {
        // Prepare one in collection by saving editable
        when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
        when(remote.saveTemplate(any)).thenAnswer((_) async => true);
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
        when(remote.saveTemplate(any)).thenAnswer((_) async => true);
        for (var i = 0; i < 6; i++) {
          await templates.add(ex('Push Up'));
          await templates.saveEditable();
        }
        expect(templates.length, 6);
        expect(templates.allowsNewTemplate, isFalse);
      });

      test('workoutToTemplate uses startTemplate for raw and creates editable from workout, notifying', () async {
        final workout = Workout(name: 'Morning')..append(WorkoutExercise(starter: ExerciseSet(ex('Push Up'))));
        when(local.startTemplate(userId: anyNamed('userId')))
            .thenAnswer((_) async => Template.empty(id: 'raw-id', order: 3));

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
  });

  group('Templates with Provider (widget)', () {
    testWidgets('of(context) returns the same instance as provided', (tester) async {
      final provided = Templates(
        remoteService: MockRemoteTemplateService(),
        service: MockTemplateService(),
        configService: MockRemoteConfigService(),
        lookForExercise: buildLookup({'Push Up': ex('Push Up')}),
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
        lookForExercise: buildLookup({'Push Up': ex('Push Up')}),
      );
      when(local.startTemplate(order: anyNamed('order'), userId: anyNamed('userId')))
          .thenAnswer((_) async => Template.empty(id: 'e1', order: 1));
      when(remote.saveTemplate(any)).thenAnswer((_) async => true);

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
