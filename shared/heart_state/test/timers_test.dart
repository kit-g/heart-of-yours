import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/timers.dart';
import 'package:provider/provider.dart';

// Simple fake service for deterministic tests (no network, no codegen)
class RecordingTimersService implements TimersService {
  final List<({String exercise, String userId, int? seconds})> setCalls = [];
  final List<String> getCalls = [];
  Map<String, int> timersToReturn = const {};

  @override
  Future<void> setRestTimer({required String exerciseName, required String userId, required int? seconds}) async {
    setCalls.add((exercise: exerciseName, userId: userId, seconds: seconds));
  }

  @override
  Future<Map<String, int>> getTimers(String userId) async {
    getCalls.add(userId);
    return timersToReturn;
  }
}

void main() {
  group('Timers (unit)', () {
    late RecordingTimersService service;
    late Timers timers;
    late int notifications;

    setUp(() {
      service = RecordingTimersService();
      timers = Timers(service: service);
      notifications = 0;
      timers.addListener(() => notifications++);
    });

    test('operator [] returns expected values', () async {
      timers.userId = 'user-1';

      await timers.setRestTimer('Push Up', 30);
      expect(timers['Push Up'], 30);
      expect(timers['Squat'], isNull);

      expect(service.setCalls.length, 1);
      expect(service.setCalls.first, (exercise: 'Push Up', userId: 'user-1', seconds: 30));
    });

    test('setRestTimer with userId set: updates map, notifies, and records service call', () async {
      timers.userId = 'u1';

      expect(notifications, 0);
      await timers.setRestTimer('Push Up', 30);

      expect(timers['Push Up'], 30);
      expect(notifications, 1);
      expect(service.setCalls, [
        (exercise: 'Push Up', userId: 'u1', seconds: 30),
      ]);
    });

    test('setRestTimer with userId null: does nothing (no map, no notify, no service)', () async {
      timers.userId = null;

      await timers.setRestTimer('Push Up', 30);

      expect(timers['Push Up'], isNull);
      expect(notifications, 0);
      expect(service.setCalls, isEmpty);
      expect(service.getCalls, isEmpty);
    });

    test('remove with userId set: removes from map, notifies, and records service call with null seconds', () async {
      timers.userId = 'u1';
      await timers.setRestTimer('Push Up', 30);
      notifications = 0; // reset counter
      service.setCalls.clear();

      await timers.remove('Push Up');
      expect(timers['Push Up'], isNull);
      expect(notifications, 1);
      expect(service.setCalls, [
        (exercise: 'Push Up', userId: 'u1', seconds: null),
      ]);
    });

    test('remove with userId null: still notifies but no service call', () async {
      timers.userId = null;
      expect(timers['Push Up'], isNull);
      expect(notifications, 0);

      await timers.remove('Push Up');
      expect(notifications, 1, reason: 'remove should notify even if key absent');
      expect(service.setCalls, isEmpty);
      expect(service.getCalls, isEmpty);
    });

    test('init with userId set: loads from service, merges, and notifies once', () async {
      timers.userId = 'user-1';
      service.timersToReturn = {
        'Push Up': 30,
        'Squat': 45,
      };

      expect(notifications, 0);
      await timers.init();

      expect(timers['Push Up'], 30);
      expect(timers['Squat'], 45);
      expect(notifications, 1);
      expect(service.getCalls, ['user-1']);
    });

    test('init with userId null: does nothing and does not notify', () async {
      timers.userId = null;
      await timers.init();
      expect(notifications, 0);
      expect(service.getCalls, isEmpty);
      expect(service.setCalls, isEmpty);
    });

    test('onSignOut clears userId and timers without notifying', () async {
      timers.userId = 'user-1';
      service.timersToReturn = {'Push Up': 30};
      await timers.init();
      expect(timers['Push Up'], 30);
      notifications = 0;

      timers.onSignOut();
      expect(timers.userId, isNull);
      expect(timers['Push Up'], isNull);
      expect(notifications, 0, reason: 'onSignOut does not call notifyListeners');
    });

    test('setRestTimer updates same key multiple times and ends with last value', () async {
      timers.userId = 'u1';

      await timers.setRestTimer('Push Up', 15);
      await timers.setRestTimer('Push Up', 25);
      await timers.setRestTimer('Push Up', 35);

      expect(timers['Push Up'], 35);
      expect(service.setCalls.length, 3);
      expect(service.setCalls.last, (exercise: 'Push Up', userId: 'u1', seconds: 35));
    });
  });

  group('Timers with Provider (widget)', () {
    testWidgets('of(context) returns the same instance as provided', (tester) async {
      late Timers fromOf;
      final service = RecordingTimersService();
      final provided = Timers(service: service);

      await tester.pumpWidget(
        ChangeNotifierProvider<Timers>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              fromOf = Timers.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(fromOf, provided), isTrue);
    });

    testWidgets('watch(context) rebuilds widget on notifyListeners (init/set/remove)', (tester) async {
      final service = RecordingTimersService();
      final provided = Timers(service: service);
      provided.userId = 'user-1';

      service.timersToReturn = {'Push Up': 30};

      var builds = 0;

      Widget consumer() {
        return Builder(
          builder: (context) {
            final mapValue = Timers.watch(context)['Push Up'];
            builds++;
            return Text('rest=${mapValue ?? -1}', textDirection: TextDirection.ltr);
          },
        );
      }

      await tester.pumpWidget(
        ChangeNotifierProvider<Timers>.value(
          value: provided,
          child: consumer(),
        ),
      );

      final initialBuilds = builds;
      expect(initialBuilds, 1);

      // init should notify and rebuild
      await provided.init();
      await tester.pump();
      expect(builds, initialBuilds + 1);

      // set should notify and rebuild
      await provided.setRestTimer('Push Up', 45);
      await tester.pump();
      expect(builds, initialBuilds + 2);

      // remove should notify and rebuild
      await provided.remove('Push Up');
      await tester.pump();
      expect(builds, initialBuilds + 3);

      expect(find.byType(Text), findsOneWidget);
    });
  });
}
