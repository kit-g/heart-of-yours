import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'test_utils.dart';

class _FakePreviousService implements PreviousExerciseService {
  final requested = <String>[];
  Map<ExerciseId, List<Map<String, dynamic>>> response;
  Object? error;

  new({this.response = const {}});

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

    group('matching', () {
      final squat = Exercise.fromJson({'id': 'squat', 'name': 'Squat', 'category': 'Barbell', 'target': 'Legs'});

      WorkoutExercise sets(List<SetType> types) {
        final exercise = WorkoutExercise(starter: ExerciseSet(squat, setType: types.first));
        for (final type in types.skip(1)) {
          exercise.add(ExerciseSet(squat, setType: type));
        }
        return exercise;
      }

      setUp(() async {
        sut = PreviousExercises(
          service: _FakePreviousService(
            response: {
              'squat': [
                {'weight': 40, 'reps': 10, 'set_type': 'warmup'},
                {'weight': 100, 'reps': 5},
                {'weight': 105, 'reps': 3, 'set_type': 'failure'},
              ],
            },
          ),
        )..userId = 'user-1';
        await sut.init();
      });

      test('lines warm-ups up with warm-ups and working sets with working sets', () {
        final today = sets([.warmup, .warmup, .normal, .drop]);

        expect(sut.matching(today, 0), {'weight': 40, 'reps': 10, 'set_type': 'warmup'});
        expect(sut.matching(today, 1), isNull);
        expect(sut.matching(today, 2), {'weight': 100, 'reps': 5});
        expect(sut.matching(today, 3), {'weight': 105, 'reps': 3, 'set_type': 'failure'});
      });

      test('a session without warm-ups still lines its sets up with last working ones', () {
        final today = sets([.normal, .normal]);

        expect(sut.matching(today, 0)?['weight'], 100);
        expect(sut.matching(today, 1)?['weight'], 105);
      });
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

  test('lastDone is the start of the newest session that has the exercise, and null for none (#135)', () async {
    final sut = PreviousExercises(
      service: _FakePreviousService(
        response: {
          'squat': [
            {'weight': 100, 'reps': 5, 'workout_start': '2026-10-03T08:00:00.000Z'},
          ],
          // a row from before the column carried its start
          'plank': [
            {'duration': 60},
          ],
        },
      ),
    )..userId = 'user-1';
    await sut.init();

    expect(sut.lastDone('squat'), DateTime.utc(2026, 10, 3, 8));
    expect(sut.lastDone('plank'), isNull);
    expect(sut.lastDone('deadlift'), isNull);
  });

  group('before a moment (a past workout\'s editor)', () {
    test('reads last time as of the workout\'s start, under the same user, leaving the app\'s own alone', () async {
      final service = _FakePreviousService(
        response: {
          'squat': [
            {'set_id': 'itself'},
          ],
        },
      );
      final asked = <(String, DateTime)>[];
      final app = PreviousExercises(
        service: service,
        readBefore: (userId, before) async {
          asked.add((userId, before));
          return {
            'squat': [
              {'set_id': 'before'},
            ],
          };
        },
      )..userId = 'user-1';
      await app.init();

      final start = DateTime.utc(2026, 10, 3, 8);
      final scoped = app.before(start);
      await scoped.init();

      expect(asked, [('user-1', start)]);
      expect(scoped.last('squat'), {'set_id': 'before'});
      expect(app.last('squat'), {'set_id': 'itself'});
      expect(service.requested, ['user-1'], reason: 'the scoped copy never reads the undated table');
    });

    test('without a dated reader it knows no last time rather than the workout itself', () async {
      final service = _FakePreviousService(
        response: {
          'squat': [
            {'set_id': 'itself'},
          ],
        },
      );
      final scoped = (PreviousExercises(service: service)..userId = 'user-1').before(DateTime.utc(2026));
      await scoped.init();

      expect(scoped.last('squat'), isNull);
      expect(service.requested, isEmpty);
    });

    test('a copy disposed before its read lands does not notify', () async {
      final scoped = PreviousExercises(
        service: _FakePreviousService(),
        readBefore: (_, _) async => {},
      )..userId = 'user-1';
      final copy = scoped.before(DateTime.utc(2026));
      final reading = copy.init();
      copy.dispose();

      await expectLater(reading, completes);
    });
  });
}
