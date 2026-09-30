import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Opt-in answers following the account (#138): the settings codec, the
/// device's timestamps, and the reconciling between the two.
class _Account with ChangeNotifier implements SettingsAccount {
  @override
  User? user;

  @override
  bool isAnonymous;

  final saved = <Settings>[];

  new() : isAnonymous = false;

  /// Stands in for PUT /accounts after heart-api#89: what is sent is merged
  /// into what is held, and the result comes back.
  @override
  Future<Settings?> saveSettings(Settings settings) async {
    saved.add(settings);
    user = user?.copyWith(settings: settings);
    notifyListeners();
    return settings;
  }

  void arrive(Settings settings) {
    user = User(id: 'muffin', displayName: 'Muffin', email: null, avatar: null, createdAt: null, settings: settings);
    notifyListeners();
  }
}

void main() {
  const feature = Feature.muscleMap;
  final earlier = DateTime.utc(2026, 9, 1, 10);
  final later = DateTime.utc(2026, 9, 20, 10);

  Settings settingsWith({required bool on, required DateTime at, Map<String, dynamic> extra = const {}}) {
    return Settings(
      extra: {
        ...extra,
        'features': {
          'muscleMap': {'on': on, 'at': at.toIso8601String()},
        },
      },
    );
  }

  group('the settings codec', () {
    test('reads what it wrote', () {
      final written = withFeatureRecords(const Settings(), {feature: (on: true, at: later)});
      expect(featureRecordsOf(written), {feature: (on: true, at: later)});
    });

    test('keeps every other key, and features this version does not know', () {
      const settings = Settings(
        themeMode: 'dark',
        extra: {
          'somethingElse': 1,
          'features': {
            'voiceRestTimer': {'on': true, 'at': '2026-09-01T00:00:00.000Z'},
          },
        },
      );

      final written = withFeatureRecords(settings, {feature: (on: false, at: later)});

      expect(written.themeMode, 'dark');
      expect(written.extra['somethingElse'], 1);
      expect((written.extra['features'] as Map)['voiceRestTimer'], {'on': true, 'at': '2026-09-01T00:00:00.000Z'});
      expect(featureRecordsOf(written), {feature: (on: false, at: later)});
    });

    test('is lenient: a malformed or missing entry reads as no answer, never a throw', () {
      for (final extra in <Map<String, dynamic>>[
        {},
        {'features': 'nope'},
        {
          'features': {'muscleMap': 'on'},
        },
        {
          'features': {
            'muscleMap': {'on': 'yes', 'at': '2026-09-01T00:00:00Z'},
          },
        },
        {
          'features': {
            'muscleMap': {'on': true, 'at': 'yesterday'},
          },
        },
      ]) {
        expect(featureRecordsOf(Settings(extra: extra)), isEmpty, reason: '$extra');
      }
    });

    test('pins the wire keys: renaming one would lose every stored answer', () {
      final written = withFeatureRecords(const Settings(), {feature: (on: true, at: later)});
      expect(written.toMap()['features'], {
        'muscleMap': {'on': true, 'at': later.toIso8601String()},
      });
    });
  });

  group('the device\'s answers', () {
    late Preferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = Preferences();
      await preferences.init();
    });

    test('a real answer is recorded with when it was given; an unanswered offer is not', () {
      preferences.markOffered(feature);
      expect(preferences.featureRecords, isEmpty);

      final before = DateTime.timestamp();
      preferences.answerOffer(feature, yes: true);
      final (:on, :at) = preferences.featureRecords[feature]!;
      expect(on, isTrue);
      expect(at.isBefore(before), isFalse);
    });

    test('adopting another device\'s answer retires an offer and a notice still on screen, and notifies once', () {
      preferences.markOffered(feature);
      preferences.answerOffer(feature, yes: false);
      expect(preferences.owesDeclineNotice(feature), isTrue);
      var notifications = 0;
      preferences.addListener(() => notifications++);

      preferences.adoptFeatureRecords({feature: (on: true, at: later)});

      expect(preferences.isOn(feature), isTrue);
      expect(preferences.owesDeclineNotice(feature), isFalse);
      expect(preferences.featureRecords[feature], (on: true, at: later));
      expect(notifications, 1);
    });

    test('adopting nothing is silent', () {
      var notifications = 0;
      preferences.addListener(() => notifications++);
      preferences.adoptFeatureRecords({});
      expect(notifications, 0);
    });
  });

  group('FeatureSync', () {
    late Preferences preferences;
    late _Account account;
    late FeatureSync sync;

    Future<void> boot({Map<String, Object> stored = const {}}) async {
      SharedPreferences.setMockInitialValues(stored);
      preferences = Preferences();
      await preferences.init();
      account = _Account();
      sync = FeatureSync(preferences: preferences, auth: account);
      addTearDown(sync.dispose);
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('an answer from another device that is newer is taken here; nothing is written back', () async {
      await boot(
        stored: {
          'feature-muscleMap': 'off',
          'feature-muscleMap-at': earlier.toIso8601String(),
        },
      );

      account.arrive(settingsWith(on: true, at: later));
      await settle();

      expect(preferences.isOn(feature), isTrue);
      expect(account.saved, isEmpty);
    });

    test('a newer answer here is written to the account, keeping what else it holds', () async {
      await boot(
        stored: {
          'feature-muscleMap': 'on',
          'feature-muscleMap-at': later.toIso8601String(),
        },
      );

      account.arrive(settingsWith(on: false, at: earlier, extra: {'kept': true}));
      await settle();

      expect(preferences.isOn(feature), isTrue);
      final [saved] = account.saved;
      expect(featureRecordsOf(saved), {feature: (on: true, at: later)});
      expect(saved.extra['kept'], isTrue);
    });

    test('a second phone that was never asked takes the answer and does not ask', () async {
      await boot();
      account.arrive(settingsWith(on: false, at: earlier));
      await settle();

      expect(preferences.featureAnswer(feature), FeatureAnswer.off);
      expect(preferences.shouldOffer(feature), isFalse);
      expect(account.saved, isEmpty);
    });

    test('answering here goes up at once, and the echo is not written again', () async {
      await boot();
      account.arrive(const Settings());
      await settle();

      preferences.setFeature(feature, on: true);
      await settle();
      await settle();

      expect(account.saved, hasLength(1));
      expect(featureRecordsOf(account.saved.single)[feature]?.on, isTrue);
    });

    test('an anonymous session keeps its answers on the device', () async {
      await boot();
      account.isAnonymous = true;
      account.arrive(settingsWith(on: true, at: later));
      await settle();

      preferences.setFeature(feature, on: false);
      await settle();

      expect(account.saved, isEmpty);
      expect(preferences.isOn(feature), isFalse);
    });

    test('a failed write leaves the device\'s answer standing and is reported', () async {
      SharedPreferences.setMockInitialValues({});
      preferences = Preferences();
      await preferences.init();
      final failing = _FailingAccount();
      final errors = <Object?>[];
      final sync = FeatureSync(
        preferences: preferences,
        auth: failing,
        onError: (error, {stacktrace}) => errors.add(error),
      );
      addTearDown(sync.dispose);

      failing.arrive(const Settings());
      preferences.setFeature(feature, on: true);
      await settle();

      expect(preferences.isOn(feature), isTrue);
      expect(errors, isNotEmpty);
    });
  });
}

class _FailingAccount extends _Account {
  @override
  Future<Settings?> saveSettings(Settings settings) => Future.error(StateError('offline'));
}
