import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        'weightUnit': 'Metric',
        'distanceUnit': 'Imperial',
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
      expect(sut.getThemeMode(), 'dark');

      await sut.setThemeMode(null);
      expect(sut.getThemeMode(), isNull);
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
      expect(prefs.getString('weightUnit'), 'Imperial');
    });

    test('setDistanceUnit persists and notifies once', () async {
      await sut.init();
      final probe = ListenerProbe()..attach(sut);
      final ok = await sut.setDistanceUnit(MeasurementUnit.imperial);
      expect(ok, isTrue);
      expect(sut.distanceUnit, MeasurementUnit.imperial);
      expect(probe.notifications, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('distanceUnit'), 'Imperial');
    });
  });

  group('formatting and conversions', () {
    test('weight() and distance() format integers without decimals in metric', () async {
      await sut.init(locale: const Locale('de', 'DE'));
      // metric: value used directly; 1 -> "1"
      expect(sut.weight(1), '1');
      expect(sut.distance(1), '1');
      // non-integer shows two decimals
      expect(sut.weight(1.234), '1.23');
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
}
