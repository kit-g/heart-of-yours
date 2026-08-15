import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'mocks.mocks.dart';

/// Counting stand-ins for every notifier [clearState] fans out to.
///
/// They count dispatches instead of delegating to the real `onSignOut` —
/// each class's clearing behavior is covered by its own suite; this suite
/// is about the fan-out itself.
class _Alarms extends Alarms {
  int calls = 0;

  @override
  void onSignOut() => calls++;
}

class _Auth extends Auth {
  int calls = 0;

  new() : super(service: MockAccountService(), firebase: MockFirebaseAuth());

  @override
  FutureOr<void> onSignOut() => calls++;
}

class _Charts extends Charts {
  int calls = 0;

  new() : super(service: MockChartPreferenceService());

  @override
  void onSignOut() => calls++;
}

class _Exercises extends Exercises {
  int calls = 0;

  new() : super(service: MockExerciseService(), remoteService: MockRemoteExerciseService());

  @override
  void onSignOut() => calls++;
}

class _FakePreviousService implements PreviousExerciseService {
  @override
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSets(String userId) async => {};
}

class _Previous extends PreviousExercises {
  int calls = 0;

  new() : super(service: _FakePreviousService());

  @override
  void onSignOut() => calls++;
}

class _RemoteConfig extends RemoteConfig {
  int calls = 0;

  new() : super(service: MockRemoteConfigService());

  @override
  void onSignOut() => calls++;
}

class _Stats extends Stats {
  int calls = 0;

  new() : super(onError: null, service: MockLocalStatsService());

  @override
  void onSignOut() => calls++;
}

class _Templates extends Templates {
  int calls = 0;

  new()
    : super(
        remoteService: MockRemoteTemplateService(),
        service: MockTemplateService(),
        configService: MockRemoteConfigService(),
        folderService: MockLocalTemplateFolderService(),
        remoteFolderService: MockApiTemplateFolderService(),
        filingService: MockRemoteTemplateFilingService(),
      );

  @override
  void onSignOut() => calls++;
}

class _Timers extends Timers {
  int calls = 0;

  new() : super(service: MockTimersService());

  @override
  void onSignOut() => calls++;
}

class _Goals extends Goals {
  int calls = 0;

  new() : super(service: MockLocalGoalService(), remoteService: MockGoalService());

  @override
  void onSignOut() => calls++;
}

class _Workouts extends Workouts {
  int calls = 0;

  new() : super(service: MockWorkoutService(), remoteService: MockRemoteWorkoutService());

  @override
  void onSignOut() => calls++;
}

/// A local mirror that holds nothing. [clearState] never reaches storage — it
/// only fans out — so the store just has to exist.
class _NoHealthStore implements HealthSampleStore {
  @override
  Future<void> storeHealthSamples(Iterable<HealthSample> samples, String userId) async {}

  @override
  Future<List<HealthSample>> getHealthSamples({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<DateTime?> lastHealthSampleAt({required String userId, required HealthMetric metric}) async => null;

  @override
  Future<List<HealthDailyValue>> getDailyHealth({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<void> deleteHealthSamples(String userId) async {}
}

class _Health extends Health {
  int calls = 0;

  new() : super(device: const UnsupportedHealthStore(), local: _NoHealthStore());

  @override
  void onSignOut() => calls++;
}

/// Resolves the heart_state package root whether the runner's working
/// directory is the package itself or the repository root.
Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/lib/src/clear.dart').existsSync()) {
      return dir;
    }
    final nested = Directory('${dir.path}/shared/heart_state');
    if (File('${nested.path}/lib/src/clear.dart').existsSync()) {
      return nested;
    }
    dir = dir.parent;
  }
  fail('could not locate the heart_state package root from ${Directory.current.path}');
}

void main() {
  group('clearState fan-out', () {
    late _Alarms alarms;
    late _Auth auth;
    late _Charts charts;
    late _Exercises exercises;
    late _Goals goals;
    late _Health health;
    late _Previous previous;
    late _RemoteConfig config;
    late _Stats stats;
    late _Templates templates;
    late _Timers timers;
    late _Workouts workouts;
    late BuildContext capturedContext;

    Future<void> pumpProviders(WidgetTester tester) async {
      alarms = _Alarms();
      auth = _Auth();
      charts = _Charts();
      exercises = _Exercises();
      goals = _Goals();
      health = _Health();
      previous = _Previous();
      config = _RemoteConfig();
      stats = _Stats();
      templates = _Templates();
      timers = _Timers();
      workouts = _Workouts();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<Alarms>.value(value: alarms),
            ChangeNotifierProvider<Auth>.value(value: auth),
            ChangeNotifierProvider<Charts>.value(value: charts),
            ChangeNotifierProvider<Exercises>.value(value: exercises),
            ChangeNotifierProvider<Goals>.value(value: goals),
            ChangeNotifierProvider<Health>.value(value: health),
            ChangeNotifierProvider<PreviousExercises>.value(value: previous),
            Provider<RemoteConfig>.value(value: config),
            ChangeNotifierProvider<Stats>.value(value: stats),
            ChangeNotifierProvider<Templates>.value(value: templates),
            ChangeNotifierProvider<Timers>.value(value: timers),
            ChangeNotifierProvider<Workouts>.value(value: workouts),
          ],
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    List<int> counts() {
      return [
        alarms.calls,
        auth.calls,
        charts.calls,
        exercises.calls,
        goals.calls,
        health.calls,
        previous.calls,
        config.calls,
        stats.calls,
        templates.calls,
        timers.calls,
        workouts.calls,
      ];
    }

    testWidgets('invokes onSignOut on every registered notifier exactly once', (tester) async {
      await pumpProviders(tester);

      clearState(capturedContext);

      expect(counts(), everyElement(1), reason: 'each notifier signs out exactly once per clearState call');
    });

    testWidgets('is not memoized: a second sign-out dispatches again', (tester) async {
      await pumpProviders(tester);

      clearState(capturedContext);
      clearState(capturedContext);

      expect(counts(), everyElement(2));
    });
  });

  group('clearState completeness (source-level)', () {
    // The classic regression: a notifier gains per-user state and implements
    // SignOutStateSentry, but nobody adds it to clearState — the previous
    // user's data survives sign-out. These tests scan the package source so
    // that adding an implementer without registering it fails loudly here.
    test('every SignOutStateSentry implementer in the package is in the fan-out', () {
      final root = _packageRoot();
      final src = Directory('${root.path}/lib/src');

      final implementers = <String>{};
      final classHeader = RegExp(r'class\s+(\w+)[^{]*\bSignOutStateSentry\b');
      final sources = src.listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final file in sources) {
        for (final match in classHeader.allMatches(file.readAsStringSync())) {
          implementers.add(match.group(1)!);
        }
      }

      final clear = File('${src.path}/clear.dart').readAsStringSync();
      final fanOutCall = RegExp(r'(\w+)\.of\(context\)\.onSignOut\(\)');
      final fanned = [for (final match in fanOutCall.allMatches(clear)) match.group(1)!];

      expect(implementers, isNotEmpty, reason: 'the scan itself must find the known implementers');
      expect(
        fanned.toSet(),
        implementers,
        reason:
            'clearState must sign out exactly the SignOutStateSentry implementers — '
            'an implementer missing here keeps the previous user\'s state after sign-out',
      );
      expect(
        fanned.length,
        fanned.toSet().length,
        reason: 'no notifier should be signed out twice',
      );
    });

    test('the fan-out list is the twelve known notifiers', () {
      final clear = File('${_packageRoot().path}/lib/src/clear.dart').readAsStringSync();
      final fanOutCall = RegExp(r'(\w+)\.of\(context\)\.onSignOut\(\)');
      final fanned = {for (final match in fanOutCall.allMatches(clear)) match.group(1)!};

      expect(fanned, {
        'Alarms',
        'Auth',
        'Charts',
        'Exercises',
        'Goals',
        'Health',
        'PreviousExercises',
        'RemoteConfig',
        'Stats',
        'Templates',
        'Timers',
        'Workouts',
      });
    });
  });
}
