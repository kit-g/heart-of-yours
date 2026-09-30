import 'dart:async';

import 'package:heart/core/env/sentry.dart';

/// Runs once around every test file in the app suite (a `flutter test`
/// convention: the file's name is what makes it apply).
///
/// Reported errors stay silent here. Tests that expect an error assert on it
/// through their mocks, and printing every mocked failure and simulated
/// outage buried the suite's verdict under thousands of lines of stack traces.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  echoReportedErrors = false;
  await testMain();
}
