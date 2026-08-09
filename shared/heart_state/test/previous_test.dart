import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'test_utils.dart';

class _FakePreviousService implements PreviousExerciseService {
  final requested = <String>[];
  Map<ExerciseId, List<Map<String, dynamic>>> response;
  Object? error;

  _FakePreviousService({this.response = const {}});

  @override
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSets(String userId) async {
    requested.add(userId);
    if (error case Object e) throw e;
    return response;
  }
}

void main() {
  group('PreviousExercises init', () {
    test('without a userId does not touch the service and does not notify', () async {
      final service = _FakePreviousService();
      final sut = PreviousExercises(service: service);
      final probe = ListenerProbe()..attach(sut);

      await sut.init();

      expect(service.requested, isEmpty);
      expect(probe.notifications, 0);
    });

    test('with a userId loads previous sets for that user and notifies once', () async {
      final service = _FakePreviousService(
        response: {
          'squat': [
            {'weight': 100, 'reps': 5},
            {'weight': 105, 'reps': 3},
          ],
        },
      );
      final sut = PreviousExercises(service: service)..userId = 'user-1';
      final probe = ListenerProbe()..attach(sut);

      await sut.init();

      expect(service.requested, ['user-1']);
      expect(probe.notifications, 1);
      expect(sut.at('squat', 0), {'weight': 100, 'reps': 5});
      expect(sut.last('squat'), {'weight': 105, 'reps': 3});
    });

    test('replaces previously loaded data instead of merging', () async {
      final service = _FakePreviousService(
        response: {
          'squat': [
            {'weight': 100},
          ],
        },
      );
      final sut = PreviousExercises(service: service)..userId = 'user-1';
      await sut.init();

      service.response = {
        'bench': [
          {'weight': 60},
        ],
      };
      await sut.init();

      expect(sut.last('squat'), isNull, reason: 'stale exercises are dropped on reload');
      expect(sut.last('bench'), {'weight': 60});
    });

    test('propagates service errors and keeps listeners quiet', () async {
      final service = _FakePreviousService()..error = StateError('offline');
      final sut = PreviousExercises(service: service)..userId = 'user-1';
      final probe = ListenerProbe()..attach(sut);

      await expectLater(sut.init(), throwsStateError);
      expect(probe.notifications, 0);
    });
  });

  group('PreviousExercises lookups', () {
    late PreviousExercises sut;

    setUp(() async {
      sut = PreviousExercises(
        service: _FakePreviousService(
          response: {
            'squat': [
              {'weight': 100, 'reps': 5},
              {'weight': 105, 'reps': 3},
            ],
            'plank': [],
          },
        ),
      )..userId = 'user-1';
      await sut.init();
    });

    test('at returns the set at the index', () {
      expect(sut.at('squat', 1), {'weight': 105, 'reps': 3});
    });

    test('at returns null for an unknown exercise', () {
      expect(sut.at('deadlift', 0), isNull);
    });

    test('at returns null when the index is out of range', () {
      expect(sut.at('squat', 2), isNull);
    });

    test('at returns null for a negative index', () {
      expect(sut.at('squat', -1), isNull);
    });

    test('last returns the final set', () {
      expect(sut.last('squat'), {'weight': 105, 'reps': 3});
    });

    test('last returns null for an unknown exercise and for an empty history', () {
      expect(sut.last('deadlift'), isNull);
      expect(sut.last('plank'), isNull);
    });
  });

  group('PreviousExercises onSignOut', () {
    test('clears loaded sets without notifying', () async {
      final sut = PreviousExercises(
        service: _FakePreviousService(
          response: {
            'squat': [
              {'weight': 100},
            ],
          },
        ),
      )..userId = 'user-1';
      await sut.init();
      final probe = ListenerProbe()..attach(sut);

      sut.onSignOut();

      expect(sut.at('squat', 0), isNull);
      expect(sut.last('squat'), isNull);
      expect(probe.notifications, 0);
    });
  });

  group('PreviousExercises with Provider', () {
    testWidgets('of(context) returns the provided instance', (tester) async {
      final provided = PreviousExercises(service: _FakePreviousService());
      late PreviousExercises fromOf;

      await tester.pumpWidget(
        ChangeNotifierProvider<PreviousExercises>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              fromOf = PreviousExercises.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(fromOf, provided), isTrue);
    });

    testWidgets('watch(context) rebuilds when init notifies', (tester) async {
      final provided = PreviousExercises(
        service: _FakePreviousService(
          response: {
            'squat': [
              {'weight': 100},
            ],
          },
        ),
      )..userId = 'user-1';
      var builds = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<PreviousExercises>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              PreviousExercises.watch(context);
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 1);

      await provided.init();
      await tester.pump();
      expect(builds, 2);
    });
  });
}
