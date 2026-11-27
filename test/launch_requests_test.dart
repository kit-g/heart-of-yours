// What one launch asks of the server (#676), through the real app and the
// real API client over a recording transport: each resource once, the
// account written once, and everything the opening page does not show held
// back until what it does show is in.
//
// A count that grows here is a launch that got more expensive. The gateway
// counts requests in flight per account (ten on dev), so every request added
// to the first second is added on purpose, and to this list.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

const _uid = 'u1';

/// What a launch reads for the page it opens on, each once.
const _opening = [
  'GET /v1/accounts/$_uid/goals',
  'GET /v1/accounts/$_uid/goals?archived=true',
  'GET /v1/exercise-preferences',
  // the account's own; the library comes from the CDN
  'GET /v1/exercises?owned=true',
  'GET /v1/accounts/$_uid/workouts?limit=20',
  'GET /v1/programs',
  // every program's history at once, where each program cost two (#707)
  'GET /v1/programs/history',
  'GET /v1/skips?limit=100',
  'GET /v1/template-folders',
  'GET /v1/templates',
];

/// What waits for those.
const _afterwards = ['GET /v1/anomalies?limit=100'];

/// And with Your coach on: the people, what they hid, the inbox.
const _coaching = ['GET /v1/connections', 'GET /v1/threads', 'GET /v1/workouts/hidden'];

void main() {
  late MockLocalDatabase db;
  late MockCdn cdn;
  late List<String> sent;
  late Api api;

  setUp(() {
    db = MockLocalDatabase();
    cdn = MockCdn();
    sent = [];
    // every list a launch reads, empty, on an account that is itself
    final account = <String, dynamic>{
      'id': _uid,
      'email': 'muffin@heart.test',
      for (final list in const [
        'anomalies',
        'connections',
        'exercises',
        'folders',
        'goals',
        'hidden',
        'preferences',
        'programs',
        'skips',
        'templates',
        'threads',
        'workouts',
      ])
        list: const <Object>[],
    };
    api = Api(
      gateway: 'api.heart.test',
      client: http_testing.MockClient((request) async {
        final Uri(:path, :query) = request.url;
        sent.add('${request.method} $path${query.isEmpty ? '' : '?$query'}');
        // the account is kept as written, as the server keeps it: what the
        // device sends up, its settings among it, comes back on the next read
        if (request.method == 'PUT' && path == '/v1/accounts') {
          account.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return http.Response(
          jsonEncode(account),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    // main() puts the build's headers on the client; start-up adds the token
    api.authenticate({});

    // flutter_cache_manager asks for it once per isolate, behind any image
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => Directory.systemTemp.path,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _pathProviderChannel,
        null,
      );
    });

    stubStartupMirror(db);
    final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    when(cdn.getExerciseLibrary(cached: anyNamed('cached'))).thenAnswer(
      (_) async => (
        (exercises: [bench], glossary: SearchGlossary.empty()),
        (version: '1', locale: 'en', etag: null),
      ),
    );
  });

  /// Launches signed in and lets start-up run through. It runs in the root
  /// zone, which pumps alone never reach: real time is what moves it.
  Future<void> launch(WidgetTester tester, {Map<String, Object> preferences = const {}}) async {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...preferences});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: _uid, email: 'muffin@heart.test'),
      ),
      settle: false,
      startUp: true,
    );
    // until the launch has said all it has to say: nothing new for a
    // while, however slow the machine
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    var seen = -1;
    var quiet = 0;
    while (quiet < 10 && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      quiet = switch (sent.length) {
        final count when count == seen && count > 0 => quiet + 1,
        _ => 0,
      };
      seen = sent.length;
    }
  }

  int at(String request) => sent.indexOf(request);

  testWidgets('a launch reads each resource once, and writes the account once', (tester) async {
    await launch(tester);

    expect([...sent]..sort(), [..._opening, ..._afterwards, 'PUT /v1/accounts']..sort());
  });

  testWidgets('what the opening page does not show waits for what it does', (tester) async {
    await launch(tester, preferences: const {'feature-yourCoach': 'on'});

    expect(
      [...sent]..sort(),
      [
        ..._opening,
        ..._afterwards,
        ..._coaching,
        'PUT /v1/accounts',
        // the device's answer to Your coach, which this server had not heard:
        // sent up once, and not again once it comes back
        'PUT /v1/accounts',
      ]..sort(),
    );
    // the goals are the profile's own, read beside the launch, not by it
    final opened = _opening.where((each) => !each.contains('/goals')).map(at).reduce(max);
    for (final later in [..._afterwards, ..._coaching]) {
      expect(at(later), greaterThan(opened), reason: '$later went out among the opening reads');
    }
  });
}
