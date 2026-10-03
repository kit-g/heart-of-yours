import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'test_utils.dart';

void main() {
  late Preferences sut;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sut = Preferences();
  });

  group('Provider helpers', () {
    testWidgets('of(context) returns the provided instance', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final got = Preferences.of(context);
              expect(identical(got, sut), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('watch(context) rebuilds on notifyListeners from setWeightUnit', (tester) async {
      await sut.init(locale: const Locale('en', 'US'));
      int builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: sut,
          child: Builder(
            builder: (context) {
              // access a watched value to set up dependency
              final _ = Preferences.watch(context).weightUnit;
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 1);

      sut.setWeightUnit(MeasurementUnit.metric);
      await tester.pump();
      expect(builds, 2);
    });
  });

  group('init()', () {
    test('sets isInitialized true, selects units by locale, and notifies once', () async {
      final probe = ListenerProbe()..attach(sut);
      await sut.init(locale: const Locale('en', 'US')); // imperial country
      expect(sut.isInitialized, isTrue);
      expect(sut.weightUnit, MeasurementUnit.imperial);
      expect(sut.distanceUnit, MeasurementUnit.imperial);
      expect(probe.notifications, 1);
    });

    test('defaults to metric outside imperial countries', () async {
      await sut.init(locale: const Locale('de', 'DE'));
      expect(sut.weightUnit, MeasurementUnit.metric);
      expect(sut.distanceUnit, MeasurementUnit.metric);
    });

    test('uses stored units if present, overriding locale defaults', () async {
      SharedPreferences.setMockInitialValues({
        'weightUnit': 'metric',
        'distanceUnit': 'imperial',
      });
      sut = Preferences();
      await sut.init(locale: const Locale('en', 'US'));
      expect(sut.weightUnit, MeasurementUnit.metric);
      expect(sut.distanceUnit, MeasurementUnit.imperial);
    });
  });

  group('defaultUnit(countryCode)', () {
    test('imperial for US/LR/MM and metric otherwise', () {
      expect(sut.defaultUnit('US'), MeasurementUnit.imperial);
      expect(sut.defaultUnit('LR'), MeasurementUnit.imperial);
      expect(sut.defaultUnit('MM'), MeasurementUnit.imperial);
      expect(sut.defaultUnit('DE'), MeasurementUnit.metric);
      expect(sut.defaultUnit(null), MeasurementUnit.metric);
    });
  });

  group('base color per user', () {
    test('set/get and removal; null userId returns null', () async {
      await sut.init();

      // null userId
      final rNull = sut.setBaseColor(null, '#ff0000');
      expect(rNull, isNull);
      expect(sut.getBaseColor(null), isNull);

      // set and get for a user
      final ok = await sut.setBaseColor('u1', '#112233');
      expect(ok, isTrue);
      expect(sut.getBaseColor('u1'), '#112233');

      // remove when hex is null
      final removed = await sut.setBaseColor('u1', null);
      expect(removed, isTrue);
      expect(sut.getBaseColor('u1'), isNull);
    });
  });

  group('theme mode', () {
    test('setThemeMode stores or removes, getThemeMode reads back', () async {
      await sut.init();

      await sut.setThemeMode(ThemeMode.dark);
      expect(sut.themeMode, 'dark');

      await sut.setThemeMode(null);
      expect(sut.themeMode, isNull);
    });
  });

  group('measurement units persistence and notifications', () {
    test('setWeightUnit persists and notifies once', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);
      final ok = await sut.setWeightUnit(MeasurementUnit.imperial);
      expect(ok, isTrue);
      expect(sut.weightUnit, MeasurementUnit.imperial);
      expect(probe.notifications, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('weightUnit'), 'imperial');
    });

    test('setDistanceUnit persists and notifies once', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);
      final ok = await sut.setDistanceUnit(MeasurementUnit.imperial);
      expect(ok, isTrue);
      expect(sut.distanceUnit, MeasurementUnit.imperial);
      expect(probe.notifications, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('distanceUnit'), 'imperial');
    });
  });

  group('collapsed template folders', () {
    test('folders start expanded', () async {
      await sut.init();
      expect(sut.isFolderCollapsed('f1'), isFalse);
    });

    test('toggle collapses, persists and notifies; toggling back expands', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);

      await sut.toggleFolderCollapsed('f1');
      expect(sut.isFolderCollapsed('f1'), isTrue);
      // one folder's state is not another's
      expect(sut.isFolderCollapsed('f2'), isFalse);
      expect(probe.notifications, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('collapsedTemplateFolders'), ['f1']);

      await sut.toggleFolderCollapsed('f1');
      expect(sut.isFolderCollapsed('f1'), isFalse);
      expect(prefs.getStringList('collapsedTemplateFolders'), isEmpty);
    });

    test('collapsed state survives a new Preferences instance', () async {
      SharedPreferences.setMockInitialValues({
        'collapsedTemplateFolders': ['f1'],
      });
      final revived = Preferences();
      await revived.init();
      expect(revived.isFolderCollapsed('f1'), isTrue);
    });
  });

  group('first-launch onboarding', () {
    test('reads as seen until initialized, so nothing is shown on a guess', () {
      expect(sut.onboardingSeen, isTrue);
    });

    test('initialized resolves with init, not before, and a second init is harmless', () async {
      var resolved = false;
      sut.initialized.then((_) => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);

      await sut.init();
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isTrue);

      // startup reads the store twice (see app.dart)
      await sut.init();
      expect(sut.isInitialized, isTrue);
    });

    test('a fresh device has not seen it', () async {
      await sut.init();
      expect(sut.onboardingSeen, isFalse);
    });

    test('marking it seen persists and notifies once', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);

      await sut.markOnboardingSeen();
      expect(sut.onboardingSeen, isTrue);
      expect(probe.notifications, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(Preferences.onboardingSeenKey), isTrue);
    });

    test('seen survives a new Preferences instance', () async {
      SharedPreferences.setMockInitialValues({Preferences.onboardingSeenKey: true});
      final revived = Preferences();
      await revived.init();
      expect(revived.onboardingSeen, isTrue);
    });
  });

  group('workout on the lock screen (#133)', () {
    test('is off until the user turns it on', () async {
      await sut.init();
      expect(sut.lockScreenWorkout, isFalse);
    });

    test('turning it on notifies, and survives a new instance', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);

      sut.lockScreenWorkout = true;
      expect(sut.lockScreenWorkout, isTrue);
      expect(probe.notifications, 1);

      final revived = Preferences();
      await revived.init();
      expect(revived.lockScreenWorkout, isTrue);
    });
  });

  group('opt-in features (#138)', () {
    const feature = Feature.muscleMap;

    test('a fresh device has not been asked, and the feature is off', () async {
      await sut.init();
      expect(sut.featureAnswer(feature), FeatureAnswer.unasked);
      expect(sut.isOn(feature), isFalse);
      expect(sut.shouldOffer(feature), isTrue);
    });

    test('yes turns it on, and nothing is offered or owed after', () async {
      await sut.init();
      sut.markOffered(feature);
      final probe = ListenerProbe()..attach(sut);

      sut.answerOffer(feature, yes: true);

      expect(sut.isOn(feature), isTrue);
      expect(sut.shouldOffer(feature), isFalse);
      expect(sut.owesDeclineNotice(feature), isFalse);
      expect(probe.notifications, 1);
    });

    test('no turns it off and owes exactly one notice', () async {
      await sut.init();
      sut.markOffered(feature);

      sut.answerOffer(feature, yes: false);
      expect(sut.featureAnswer(feature), FeatureAnswer.off);
      expect(sut.shouldOffer(feature), isFalse);
      expect(sut.owesDeclineNotice(feature), isTrue);

      sut.acknowledgeDeclineNotice(feature);
      expect(sut.owesDeclineNotice(feature), isFalse);
    });

    test('the notice does not outlive the session it was owed in', () async {
      await sut.init();
      sut.markOffered(feature);
      sut.answerOffer(feature, yes: false);

      final revived = Preferences();
      await revived.init();
      expect(revived.owesDeclineNotice(feature), isFalse);
      expect(revived.shouldOffer(feature), isFalse);
    });

    test('marking an offer shown is silent, and it stays up for the rest of the session', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);

      sut.markOffered(feature);
      expect(probe.notifications, 0);
      expect(sut.featureAnswer(feature), FeatureAnswer.pending);
      expect(sut.shouldOffer(feature), isTrue);
    });

    test('an offer left unanswered is a no from the next launch on: off, and never offered again', () async {
      await sut.init();
      sut.markOffered(feature);

      final revived = Preferences();
      await revived.init();
      expect(revived.shouldOffer(feature), isFalse);
      expect(revived.isOn(feature), isFalse);
      expect(revived.owesDeclineNotice(feature), isFalse);
    });

    test('the Settings switch works both ways, any number of times, and persists', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);

      for (final on in [true, false, true, false, true]) {
        sut.setFeature(feature, on: on);
        expect(sut.isOn(feature), on);
      }
      expect(probe.notifications, 5);

      final revived = Preferences();
      await revived.init();
      expect(revived.isOn(feature), isTrue);
    });

    test('the switch is the answer: it retires an offer and a notice still on screen', () async {
      await sut.init();
      sut.markOffered(feature);
      sut.setFeature(feature, on: false);
      expect(sut.shouldOffer(feature), isFalse);
      expect(sut.owesDeclineNotice(feature), isFalse);
    });

    test('marking an offer shown does not overwrite an answer', () async {
      await sut.init();
      sut.setFeature(feature, on: true);
      sut.markOffered(feature);
      expect(sut.isOn(feature), isTrue);
    });

    test('storage keys are pinned: renaming one would ask everyone again', () {
      expect(Feature.values.map((each) => each.value), ['muscleMap', 'watchApp', 'rpe']);
      expect(FeatureAnswer.values.map((each) => each.name), ['unasked', 'pending', 'on', 'off']);
    });
  });

  group('forgetUser', () {
    test('drops the uid\'s keys and leaves the device\'s, the onboarding flag first among them', () async {
      SharedPreferences.setMockInitialValues({
        Preferences.onboardingSeenKey: true,
        'themeMode': 'dark',
        'weightUnit': 'imperial',
        'baseColor-u1': 'ember',
        'healthInviteDismissed-u1': true,
        'healthAsked-u1': true,
        'baseColor-u2': 'ink',
      });
      sut = Preferences();
      await sut.init(locale: const Locale('en', 'US'));
      final probe = ListenerProbe()..attach(sut);

      await sut.forgetUser('u1');

      expect(sut.getBaseColor('u1'), isNull);
      expect(sut.healthInviteDismissed('u1'), isFalse);
      expect(sut.healthAsked('u1'), isFalse);
      expect(probe.notifications, 1);

      // another uid's, and the device's own
      expect(sut.getBaseColor('u2'), 'ink');
      expect(sut.onboardingSeen, isTrue, reason: 'the carousel is shown once per device, not once per uid');
      expect(sut.themeMode, 'dark');
      expect(sut.weightUnit, MeasurementUnit.imperial);
    });

    test('is a no-op before init', () async {
      await sut.forgetUser('u1');
    });
  });

  group('formatting and conversions', () {
    test('weight() and distance() format integers without decimals in metric', () async {
      await sut.init(locale: const Locale('de', 'DE'));
      // metric: value used directly; 1 -> "1"
      expect(sut.weight(1), '1');
      expect(sut.distance(1), '1');
      // non-integer shows up to one decimal, trailing zeros stripped
      expect(sut.weight(1.234), '1.2');
      expect(sut.distance(1.2), '1.2');
    });

    test('weight() and distance() apply conversions in imperial and format', () async {
      await sut.init(locale: const Locale('en', 'US'));
      // 1kg -> 2.20 lb (two decimals)
      expect(sut.weight(1), '2.2');
      // 1 distance unit (km) should not equal '1' when converted to miles
      expect(sut.distance(1) == '1', isFalse);
      // formatting keeps two decimals for non-integers
      final d = sut.distance(2); // 2km -> ~1.24mi
      expect(d.contains('.'), isTrue);
    });
  });

  group('What\'s new read (#216)', () {
    setUp(() => sut.init());

    test('nothing recorded on a fresh install', () {
      expect(sut.whatsNewRead, isNull);
    });

    test('marking adds, notifies once, and is silent when nothing is new', () {
      var notified = 0;
      sut.addListener(() => notified++);

      sut.markWhatsNewRead(['1.9.0/a', '1.9.0/b']);
      sut.markWhatsNewRead(['1.9.0/b']);
      sut.markWhatsNewRead(['1.10.0/c']);

      expect(sut.whatsNewRead, {'1.9.0/a', '1.9.0/b', '1.10.0/c'});
      expect(notified, 2);
    });

    test('marking nothing on a fresh install still records it as caught up', () {
      sut.markWhatsNewRead(const []);
      expect(sut.whatsNewRead, isEmpty);
    });
  });
}
