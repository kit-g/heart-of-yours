import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  late MockRemoteConfigService service;
  late RemoteConfig sut;

  setUp(() {
    service = MockRemoteConfigService();
    sut = RemoteConfig(service: service);
  });

  group('Provider helpers', () {
    testWidgets('of(context) returns the provided instance', (tester) async {
      await tester.pumpWidget(
        Provider<RemoteConfig>.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final got = RemoteConfig.of(context);
              expect(identical(got, sut), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('watch(context) returns the provided instance', (tester) async {
      await tester.pumpWidget(
        Provider<RemoteConfig>.value(
          value: sut,
          child: Builder(
            builder: (context) {
              final got = RemoteConfig.watch(context);
              expect(identical(got, sut), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('init()', () {
    test('fetches config, stringifies values, sets initialized and exposes exercisesLastSynced', () async {
      when(service.getRemoteConfig()).thenAnswer((_) async => {
            'exercisesLastSynced': '2024-01-02T03:04:05.000Z',
            'someNumber': 42,
            'aBool': true,
          });

      expect(sut.isInitialized, isFalse);
      await sut.init();

      expect(sut.isInitialized, isTrue);
      expect(sut.exercisesLastSynced, DateTime.parse('2024-01-02T03:04:05.000Z'));
      verify(service.getRemoteConfig()).called(1);
    });

    test('idempotent: second init() does not refetch', () async {
      when(service.getRemoteConfig()).thenAnswer((_) async => {
            'exercisesLastSynced': '2024-01-02T03:04:05.000Z',
          });

      await sut.init();
      await sut.init();

      verify(service.getRemoteConfig()).called(1);
    });

    test('routes errors to onError and leaves isInitialized false', () async {
      Object? err;
      sut = RemoteConfig(service: service, onError: (e, {stacktrace}) => err = e);
      when(service.getRemoteConfig()).thenThrow(Exception('boom'));

      await sut.init();

      expect(err, isNotNull);
      expect(sut.isInitialized, isFalse);
    });
  });

  group('onSignOut()', () {
    test('clears cached values (exercisesLastSynced becomes null)', () async {
      when(service.getRemoteConfig()).thenAnswer((_) async => {
            'exercisesLastSynced': '2024-01-02T03:04:05.000Z',
          });

      await sut.init();
      expect(sut.exercisesLastSynced, isNotNull);

      sut.onSignOut();
      expect(sut.exercisesLastSynced, isNull);
    });
  });
}
