import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Health data is device-only (docs/2026-09-05.health-data.md), and a Siri
/// answer may be processed off the device: the assistant's questions (#288)
/// read training data and nothing else. This holds the code that answers
/// them, and the headless entrypoint that runs it, to that — by source,
/// since what they may read is a matter of which services they touch.
void main() {
  const files = ['lib/presentation/questions/answers.dart', 'lib/core/env/questions.dart'];

  test('the questions never touch health data', () {
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('Health')), reason: '$path reads health state');
      expect(source, isNot(contains('health')), reason: '$path imports or names health');
      expect(source, isNot(contains('calories')), reason: '$path reads a health-derived value');
    }
  });

  test('the questions have no network: the mirror is the only source', () {
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('heart_api')), reason: '$path reaches the API');
      expect(source, isNot(contains('http')), reason: '$path reaches the network');
    }
  });

  test('the entrypoint is kept by the AOT build', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("@pragma('vm:entry-point')\nFuture<void> questionsMain()"));
  });
}
