import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';

import 'test_utils.dart';

void main() {
  group('AppInfo defaults', () {
    test('reads as empty rather than throwing before init', () {
      final sut = AppInfo();

      expect(sut.appName, isEmpty);
      expect(sut.version, isEmpty);
      expect(sut.build, isEmpty);
      expect(sut.fullVersion, '+');
    });
  });

  group('AppInfo init', () {
    test('adopts the package the initializer resolves', () async {
      final sut = AppInfo();

      await sut.init(() async => (appName: 'Heart', version: '1.2.3', build: '45'));

      expect(sut.appName, 'Heart');
      expect(sut.version, '1.2.3');
      expect(sut.build, '45');
      expect(sut.fullVersion, '1.2.3+45');
    });

    test('does not notify listeners', () async {
      // Current contract: version info is read via of(context), never watched,
      // so a successful init stays silent.
      final sut = AppInfo();
      final probe = ListenerProbe()..attach(sut);

      await sut.init(() async => (appName: 'Heart', version: '1.2.3', build: '45'));

      expect(probe.notifications, 0);
    });

    test('reports a failed lookup through onError and keeps the empty package', () async {
      Object? reported;
      dynamic reportedStack;
      final sut = AppInfo(
        onError: (error, {stacktrace}) {
          reported = error;
          reportedStack = stacktrace;
        },
      );

      await sut.init(() => throw StateError('no platform'));

      expect(reported, isA<StateError>());
      expect(reportedStack, isA<StackTrace>());
      expect(sut.fullVersion, '+', reason: 'a failed lookup must not corrupt the fallback');
    });

    test('swallows a failed lookup when no onError is wired', () async {
      final sut = AppInfo();

      await expectLater(sut.init(() => throw StateError('no platform')), completes);
      expect(sut.appName, isEmpty);
    });

    test('a later init overwrites an earlier one', () async {
      final sut = AppInfo();

      await sut.init(() async => (appName: 'Heart', version: '1.0.0', build: '1'));
      await sut.init(() async => (appName: 'Heart', version: '1.1.0', build: '2'));

      expect(sut.fullVersion, '1.1.0+2');
    });

    test('a failed init does not clobber a previously resolved package', () async {
      final sut = AppInfo(onError: (_, {stacktrace}) {});

      await sut.init(() async => (appName: 'Heart', version: '1.0.0', build: '1'));
      await sut.init(() => throw StateError('flaky'));

      expect(sut.fullVersion, '1.0.0+1');
    });
  });

  group('AppInfo with Provider', () {
    testWidgets('of(context) returns the provided instance', (tester) async {
      final provided = AppInfo();
      late AppInfo fromOf;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppInfo>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              fromOf = AppInfo.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(fromOf, provided), isTrue);
    });
  });
}
