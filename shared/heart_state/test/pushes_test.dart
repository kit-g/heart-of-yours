import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The push client's state (#567, #554): registering once, and settings that
/// show a change at once and put it back when the server refuses.
void main() {
  late _Service service;
  late RemoteAccess access;
  late Pushes pushes;
  late List<Object> errors;

  PushSetting topic(String name, {String delivery = 'instant', List<String> options = const ['instant', 'off']}) {
    return PushSetting(
      topic: name,
      group: 'coaching',
      name: 'Messages',
      description: 'When someone you train with writes to you',
      delivery: delivery,
      options: options,
    );
  }

  setUp(() {
    service = _Service();
    access = RemoteAccess(hasToken: () => true)..account = true;
    errors = [];
    pushes = Pushes(service: service, remote: access, onError: (error, {stacktrace}) => errors.add(error));
  });

  group('a push as it arrives', () {
    test('carries its topic and its ids, and nothing without a topic is one', () {
      final push = Push.of({'topic': 'coaching.program_changed', 'programId': 'p1'});

      expect(push?.known, PushTopic.programChanged);
      expect(push?.programId, 'p1');
      expect(push?.known?.silent, isTrue);
      expect(Push.of({'programId': 'p1'}), isNull);
      expect(Push.of({'topic': ''}), isNull);
    });

    test('one this build has never heard of is kept, unknown', () {
      final push = Push.of({'topic': 'reaction.created', 'workoutId': 'w1'});

      expect(push?.topic, 'reaction.created');
      expect(push?.known, isNull);
      expect(push?.toMap(), {'topic': 'reaction.created', 'workoutId': 'w1'});
    });
  });

  group('register', () {
    test('once per token and offset', () async {
      await pushes.register(platform: .ios, token: 't1', utcOffsetMinutes: -300);
      await pushes.register(platform: .ios, token: 't1', utcOffsetMinutes: -300);
      await pushes.register(platform: .ios, token: 't1', utcOffsetMinutes: 60);
      await pushes.register(platform: .ios, token: 't2', utcOffsetMinutes: 60);

      expect(service.calls, ['register ios t1 -300', 'register ios t1 60', 'register ios t2 60']);
    });

    test('nothing with the remote leg closed: an anonymous session has no account to push to', () async {
      access.account = false;

      await pushes.register(platform: .android, token: 't1');

      expect(service.calls, isEmpty);
    });

    test('a failure is reported and tried again next time', () async {
      service.failing = true;
      await pushes.register(platform: .android, token: 't1');
      service.failing = false;
      await pushes.register(platform: .android, token: 't1');

      expect(errors, hasLength(1));
      expect(service.calls, ['register android t1 null', 'register android t1 null']);
    });

    test('after a sign-out, or the client turning off, the same token registers again', () async {
      await pushes.register(platform: .ios, token: 't1');
      pushes.onSignOut();
      await pushes.register(platform: .ios, token: 't1');
      pushes.unregistered();
      await pushes.register(platform: .ios, token: 't1');

      expect(service.calls, hasLength(3));
    });
  });

  group('settings', () {
    test('load reads the topics and the answers for people', () async {
      service.settings = PushSettings(
        topics: [topic('coaching.message')],
        forPeople: [(topic: 'coaching.message', connectionId: 'c1', delivery: 'off')],
      );

      await pushes.load();

      expect(pushes.status, PushSettingsStatus.loaded);
      expect(pushes.topics.single.topic, 'coaching.message');
      expect(pushes.deliveryFor('coaching.message', 'c1'), 'off');
      expect(pushes.deliveryFor('coaching.message', 'c2'), isNull);
    });

    test('a failed read says so', () async {
      service.failing = true;

      await pushes.load();

      expect(pushes.status, PushSettingsStatus.failed);
      expect(errors, hasLength(1));
    });

    test('set shows at once and reaches the server', () async {
      service.settings = PushSettings(topics: [topic('coaching.message')]);
      await pushes.load();

      await pushes.set('coaching.message', 'off');

      expect(pushes.topics.single.delivery, 'off');
      expect(service.calls.last, 'set coaching.message off null');
    });

    test('a refused set is put back, and the refusal reaches the caller', () async {
      service.settings = PushSettings(topics: [topic('coaching.message')]);
      await pushes.load();
      service.failing = true;

      await expectLater(pushes.set('coaching.message', 'off'), throwsA(isA<Map>()));

      expect(pushes.topics.single.delivery, 'instant');
    });

    test('for one person: set, then back to following the topic', () async {
      service.settings = PushSettings(topics: [topic('coaching.message')]);
      await pushes.load();

      await pushes.setFor('coaching.message', 'c1', 'off');
      expect(pushes.deliveryFor('coaching.message', 'c1'), 'off');

      await pushes.setFor('coaching.message', 'c1', null);
      expect(pushes.deliveryFor('coaching.message', 'c1'), isNull);

      expect(service.calls.skip(1), ['set coaching.message off c1', 'clear coaching.message c1']);
    });

    test('a refused answer for one person is put back', () async {
      service.settings = PushSettings(
        topics: [topic('coaching.message')],
        forPeople: [(topic: 'coaching.message', connectionId: 'c1', delivery: 'off')],
      );
      await pushes.load();
      service.failing = true;

      await expectLater(pushes.setFor('coaching.message', 'c1', null), throwsA(isA<Map>()));

      expect(pushes.deliveryFor('coaching.message', 'c1'), 'off');
    });

    test('a delivery this build has no word for is kept as the server sent it', () async {
      service.settings = PushSettings(
        topics: [
          topic('coaching.message', delivery: 'weekly', options: ['weekly', 'off']),
        ],
      );
      await pushes.load();

      expect(pushes.topics.single.delivery, 'weekly');
      expect(PushDelivery.of('weekly'), isNull);
      expect(PushDelivery.of('daily'), PushDelivery.daily);
    });
  });
}

class _Service implements RemotePushService {
  final calls = <String>[];
  bool failing = false;
  PushSettings settings = const PushSettings(topics: []);

  void _call(String call) {
    calls.add(call);
    if (failing) throw {'error': 'unavailable'};
  }

  @override
  Future<void> registerDevice({required DevicePlatform platform, required String token, int? utcOffsetMinutes}) async {
    _call('register ${platform.value} $token $utcOffsetMinutes');
  }

  @override
  Future<PushSettings> getPushSettings() async {
    _call('get');
    return settings;
  }

  @override
  Future<void> setPushSetting(String topic, String delivery, {String? connectionId}) async {
    _call('set $topic $delivery $connectionId');
  }

  @override
  Future<void> clearPushSetting(String topic, {String? connectionId}) async {
    _call('clear $topic $connectionId');
  }
}
