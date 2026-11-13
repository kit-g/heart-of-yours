import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

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

class _Anomalies extends Anomalies {
  int calls = 0;

  new() : super(service: MockLocalAnomalyService(), remoteService: MockAnomalyService());

  @override
  void onSignOut() => calls++;
}

class _Auth extends Auth {
  int calls = 0;

  /// What happened before the session ended, in order.
  final List<String>? log;

  new({this.log}) : super(service: MockAccountService(), firebase: MockFirebaseAuth());

  @override
  FutureOr<void> onSignOut() {
    log?.add('sign out');
    calls++;
  }
}

class _Charts extends Charts {
  int calls = 0;

  new() : super(service: MockLocalChartService());

  @override
  void onSignOut() => calls++;
}

class _Exercises extends Exercises {
  int calls = 0;

  new()
    : super(
        service: MockExerciseService(),
        remoteService: MockRemoteExerciseService(),
        libraryService: MockExerciseLibraryService(),
        catalogService: MockLocalCatalogService(),
        preferenceService: MockRemoteExercisePreferenceService(),
      );

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

class _Programs extends Programs {
  int calls = 0;

  new()
    : super(
        service: MockLocalProgramService(),
        remoteService: MockRemoteProgramService(),
        templates: MockTemplateService(),
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

class _ApiTokens extends ApiTokens {
  int calls = 0;

  new() : super(service: MockApiTokenService());

  @override
  void onSignOut() => calls++;
}

class _Coaching extends Coaching {
  int calls = 0;

  new() : super(service: _NoCoachingService());

  @override
  void onSignOut() => calls++;
}

class _NoCoachingService implements CoachingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Roster extends Roster {
  int calls = 0;

  new() : super(service: _NoRosterService());

  @override
  void onSignOut() => calls++;
}

class _NoRosterService implements RosterService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _ClientPrograms extends ClientPrograms {
  int calls = 0;

  new() : super(service: _NoClientProgramService());

  @override
  void onSignOut() => calls++;
}

class _Pushes extends Pushes {
  int calls = 0;

  new({RemotePushService? service}) : super(service: service ?? _NoPushService());

  @override
  void onSignOut() => calls++;
}

class _NoClientProgramService implements ClientProgramService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the removal a sign-out sends, and the registration before it.
class _LoggingPushService implements RemotePushService {
  final List<String> log;

  new(this.log);

  @override
  Future<void> registerDevice({required DevicePlatform platform, required String token, int? utcOffsetMinutes}) async {}

  @override
  Future<void> unregisterDevice(String token) async => log.add('unregister $token');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoPushService implements RemotePushService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _DeviceKeys extends DeviceKeys {
  int calls = 0;

  new() : super(service: _NoKeyService(), vault: null);

  @override
  void onSignOut() => calls++;
}

class _NoKeyService implements RemoteKeyService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Messages extends Messages {
  int calls = 0;

  new() : super(service: _NoThreadService(), local: _NoThreadStore(), cipher: _NoCipher());

  @override
  void onSignOut() => calls++;
}

class _NoThreadService implements RemoteThreadService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoThreadStore implements LocalThreadService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoCipher implements ThreadCipher {
  @override
  Future<void> receive() async {}

  @override
  Stream<String> get threadKeys => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Library extends CoachLibrary {
  int calls = 0;

  new() : super(service: _NoLibraryService(), exerciseOf: (_) => null);

  @override
  void onSignOut() => calls++;
}

class _NoLibraryService implements CoachLibraryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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

class _Backfill extends Backfill {
  int calls = 0;

  new()
    : super(
        local: MockLocalMirrorService(),
        remote: MockRemoteAccountSummaryService(),
        nextPage: _noPage,
      );

  static Future<BackfillPage> _noPage() async => (stored: 0, more: false);

  @override
  void onSignOut() {
    calls++;
    super.onSignOut();
  }
}

class _Upsync extends Upsync {
  int calls = 0;

  new()
    : super(
        local: MockLocalUpsyncService(),
        remote: MockUpsyncService(),
        exercises: MockExerciseService(),
        folders: MockLocalTemplateFolderService(),
        templates: MockTemplateService(),
        workouts: MockWorkoutService(),
        goals: MockLocalGoalService(),
      );

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

  final backfilled = <(String, HealthMetric), DateTime>{};

  @override
  Future<DateTime?> healthBackfilledTo({required String userId, required HealthMetric metric}) async {
    return backfilled[(userId, metric)];
  }

  @override
  Future<void> setHealthBackfilledTo(DateTime at, {required String userId, required HealthMetric metric}) async {
    backfilled[(userId, metric)] = at;
  }

  @override
  Future<void> clearHealthBackfill(String userId) async {
    backfilled.removeWhere((key, _) => key.$1 == userId);
  }

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

/// The notifiers clear.dart signs out, as its source names them: either
/// `X.of(context).onSignOut()`, or `X.of(context)` held in a local first and
/// signed out after a wait (`final session = Auth.of(context);` … `await
/// session.onSignOut();`).
List<String> _fannedOut(String clear) {
  final direct = RegExp(r'(\w+)\.of\(context\)\.onSignOut\(\)');
  final held = RegExp(r'final (\w+) = (\w+)\.of\(context\);');
  return [
    for (final match in direct.allMatches(clear)) match.group(1)!,
    for (final match in held.allMatches(clear))
      if (RegExp('\\b${match.group(1)}\\.onSignOut\\(\\)').hasMatch(clear)) match.group(2)!,
  ];
}

void main() {
  group('clearState fan-out', () {
    late _Alarms alarms;
    late _Anomalies anomalies;
    late _ApiTokens apiTokens;
    late _Coaching coaching;
    late _Auth auth;
    late _Backfill backfill;
    late _Charts charts;
    late _Exercises exercises;
    late _Goals goals;
    late _Health health;
    late _Previous previous;
    late _Stats stats;
    late _Templates templates;
    late _Programs programs;
    late _Roster roster;
    late _Pushes pushes;
    late _DeviceKeys keys;
    late _Messages messages;
    late _Library library;
    late _ClientPrograms clientPrograms;
    late _Timers timers;
    late _Upsync upsync;
    late _Workouts workouts;
    late BuildContext capturedContext;

    Future<void> pumpProviders(WidgetTester tester, {List<String>? log}) async {
      alarms = _Alarms();
      anomalies = _Anomalies();
      apiTokens = _ApiTokens();
      coaching = _Coaching();
      auth = _Auth(log: log);
      backfill = _Backfill();
      charts = _Charts();
      exercises = _Exercises();
      goals = _Goals();
      health = _Health();
      previous = _Previous();
      stats = _Stats();
      templates = _Templates();
      programs = _Programs();
      roster = _Roster();
      pushes = _Pushes(
        service: switch (log) {
          final List<String> log => _LoggingPushService(log),
          null => null,
        },
      );
      keys = _DeviceKeys();
      messages = _Messages();
      library = _Library();
      clientPrograms = _ClientPrograms();
      timers = _Timers();
      upsync = _Upsync();
      workouts = _Workouts();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<Alarms>.value(value: alarms),
            ChangeNotifierProvider<Anomalies>.value(value: anomalies),
            ChangeNotifierProvider<ApiTokens>.value(value: apiTokens),
            ChangeNotifierProvider<Coaching>.value(value: coaching),
            ChangeNotifierProvider<Auth>.value(value: auth),
            ChangeNotifierProvider<Backfill>.value(value: backfill),
            ChangeNotifierProvider<Charts>.value(value: charts),
            ChangeNotifierProvider<Exercises>.value(value: exercises),
            ChangeNotifierProvider<Goals>.value(value: goals),
            ChangeNotifierProvider<Health>.value(value: health),
            ChangeNotifierProvider<PreviousExercises>.value(value: previous),
            ChangeNotifierProvider<Stats>.value(value: stats),
            ChangeNotifierProvider<Templates>.value(value: templates),
            ChangeNotifierProvider<Programs>.value(value: programs),
            ChangeNotifierProvider<Roster>.value(value: roster),
            ChangeNotifierProvider<Pushes>.value(value: pushes),
            ChangeNotifierProvider<DeviceKeys>.value(value: keys),
            ChangeNotifierProvider<Messages>.value(value: messages),
            ChangeNotifierProvider<CoachLibrary>.value(value: library),
            ChangeNotifierProvider<ClientPrograms>.value(value: clientPrograms),
            ChangeNotifierProvider<Timers>.value(value: timers),
            ChangeNotifierProvider<Upsync>.value(value: upsync),
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
        anomalies.calls,
        apiTokens.calls,
        coaching.calls,
        auth.calls,
        charts.calls,
        exercises.calls,
        goals.calls,
        health.calls,
        previous.calls,
        stats.calls,
        templates.calls,
        programs.calls,
        roster.calls,
        pushes.calls,
        keys.calls,
        messages.calls,
        library.calls,
        clientPrograms.calls,
        timers.calls,
        upsync.calls,
        workouts.calls,
      ];
    }

    testWidgets('invokes onSignOut on every registered notifier exactly once', (tester) async {
      await pumpProviders(tester);

      await clearState(capturedContext);

      expect(counts(), everyElement(1), reason: 'each notifier signs out exactly once per clearState call');
    });

    testWidgets('the device stops getting the account\'s pushes before the session ends (heart-api#415)', (
      tester,
    ) async {
      final log = <String>[];
      await pumpProviders(tester, log: log);
      await pushes.register(platform: .ios, token: 'fcm-1');

      await clearState(capturedContext);

      expect(log, ['unregister fcm-1', 'sign out']);
    });

    testWidgets('is not memoized: a second sign-out dispatches again', (tester) async {
      await pumpProviders(tester);

      await clearState(capturedContext);
      await clearState(capturedContext);

      expect(counts(), everyElement(2));
    });
  });

  group('eraseState', () {
    late _Alarms alarms;
    late _Anomalies anomalies;
    late _ApiTokens apiTokens;
    late _Coaching coaching;
    late _Backfill backfill;
    late _Charts charts;
    late _Exercises exercises;
    late _Goals goals;
    late _Health health;
    late _Previous previous;
    late _Stats stats;
    late _Templates templates;
    late _Programs programs;
    late _Roster roster;
    late _Pushes pushes;
    late _DeviceKeys keys;
    late _Messages messages;
    late _Library library;
    late _ClientPrograms clientPrograms;
    late _Timers timers;
    late _Upsync upsync;
    late _Workouts workouts;
    late Preferences preferences;
    late BuildContext capturedContext;

    /// The same tree as above, but with a real [Auth] over a mock Firebase —
    /// the erase is gated on the session being anonymous, which the counting
    /// stand-in above cannot say — and with [Preferences] in it.
    Future<Auth> pumpProviders(
      WidgetTester tester, {
      required MockFirebaseAuth firebase,
      required List<String> erased,
    }) async {
      SharedPreferences.setMockInitialValues({Preferences.onboardingSeenKey: true});
      alarms = _Alarms();
      anomalies = _Anomalies();
      apiTokens = _ApiTokens();
      coaching = _Coaching();
      backfill = _Backfill();
      charts = _Charts();
      exercises = _Exercises();
      goals = _Goals();
      health = _Health();
      previous = _Previous();
      stats = _Stats();
      templates = _Templates();
      programs = _Programs();
      roster = _Roster();
      pushes = _Pushes();
      keys = _DeviceKeys();
      messages = _Messages();
      library = _Library();
      clientPrograms = _ClientPrograms();
      timers = _Timers();
      upsync = _Upsync();
      workouts = _Workouts();
      preferences = Preferences();
      await preferences.init();
      final auth = Auth(
        service: MockAccountService(),
        firebase: firebase,
        googleSignIn: MockGoogleSignIn(),
        onErase: (uid) async => erased.add(uid),
      );
      // the Firebase stream's first event, which settles the session — under
      // the test's fake clock, so pumped rather than awaited on a real delay
      await tester.pump(const Duration(milliseconds: 20));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<Alarms>.value(value: alarms),
            ChangeNotifierProvider<Anomalies>.value(value: anomalies),
            ChangeNotifierProvider<ApiTokens>.value(value: apiTokens),
            ChangeNotifierProvider<Coaching>.value(value: coaching),
            ChangeNotifierProvider<Auth>.value(value: auth),
            ChangeNotifierProvider<Backfill>.value(value: backfill),
            ChangeNotifierProvider<Charts>.value(value: charts),
            ChangeNotifierProvider<Exercises>.value(value: exercises),
            ChangeNotifierProvider<Goals>.value(value: goals),
            ChangeNotifierProvider<Health>.value(value: health),
            ChangeNotifierProvider<PreviousExercises>.value(value: previous),
            ChangeNotifierProvider<Stats>.value(value: stats),
            ChangeNotifierProvider<Templates>.value(value: templates),
            ChangeNotifierProvider<Programs>.value(value: programs),
            ChangeNotifierProvider<Roster>.value(value: roster),
            ChangeNotifierProvider<Pushes>.value(value: pushes),
            ChangeNotifierProvider<DeviceKeys>.value(value: keys),
            ChangeNotifierProvider<Messages>.value(value: messages),
            ChangeNotifierProvider<CoachLibrary>.value(value: library),
            ChangeNotifierProvider<ClientPrograms>.value(value: clientPrograms),
            ChangeNotifierProvider<Timers>.value(value: timers),
            ChangeNotifierProvider<Upsync>.value(value: upsync),
            ChangeNotifierProvider<Workouts>.value(value: workouts),
            ChangeNotifierProvider<Preferences>.value(value: preferences),
          ],
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return auth;
    }

    List<int> counts() {
      return [
        alarms.calls,
        anomalies.calls,
        apiTokens.calls,
        coaching.calls,
        charts.calls,
        exercises.calls,
        goals.calls,
        health.calls,
        previous.calls,
        stats.calls,
        templates.calls,
        programs.calls,
        roster.calls,
        pushes.calls,
        keys.calls,
        messages.calls,
        library.calls,
        clientPrograms.calls,
        timers.calls,
        upsync.calls,
        workouts.calls,
      ];
    }

    testWidgets('an anonymous session: memory cleared, the uid wiped and forgotten, the session signed out', (
      tester,
    ) async {
      final erased = <String>[];
      final firebase = MockFirebaseAuth(signedIn: false);
      final auth = await pumpProviders(tester, firebase: firebase, erased: erased);
      final uid = auth.user!.id;
      await preferences.setBaseColor(uid, 'ember');

      await eraseState(capturedContext);

      expect(counts(), everyElement(1), reason: 'the same fan-out a sign-out gets');
      expect(erased, [uid]);
      expect(preferences.getBaseColor(uid), isNull);
      expect(preferences.onboardingSeen, isTrue, reason: 'the device flag survives: no carousel on the way back in');
      // signed out — and, this being mobile, straight back in under a new anonymous session
      await tester.pump(const Duration(milliseconds: 20));
      expect(auth.isAnonymous, isTrue);
      expect(auth.isLoggedIn, isTrue);
    });

    testWidgets('a session with an account is left exactly as it was', (tester) async {
      final erased = <String>[];
      final firebase = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      );
      final auth = await pumpProviders(tester, firebase: firebase, erased: erased);
      await preferences.setBaseColor('u1', 'ember');

      await eraseState(capturedContext);

      expect(counts(), everyElement(0));
      expect(erased, isEmpty);
      expect(preferences.getBaseColor('u1'), 'ember');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.isAnonymous, isFalse);
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

      final fanned = _fannedOut(File('${src.path}/clear.dart').readAsStringSync());

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

    test('the fan-out list is the twenty-three known notifiers', () {
      final fanned = _fannedOut(File('${_packageRoot().path}/lib/src/clear.dart').readAsStringSync()).toSet();

      expect(fanned, {
        'Alarms',
        'Anomalies',
        'ApiTokens',
        'Auth',
        'Backfill',
        'Charts',
        'ClientPrograms',
        'CoachLibrary',
        'Coaching',
        'DeviceKeys',
        'Exercises',
        'Goals',
        'Health',
        'Messages',
        'PreviousExercises',
        'Programs',
        'Pushes',
        'Roster',
        'Stats',
        'Templates',
        'Timers',
        'Upsync',
        'Workouts',
      });
    });
  });
}
