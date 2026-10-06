import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/logging.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// What reaches Sentry Logs from the `logging` package: the allowlisted
/// loggers' messages, at INFO and above, and never an attached error — its
/// text is where a database error's SQL and bound values, or a health reading,
/// would ride along.
void main() {
  late _Sink sink;

  setUp(() => sink = _Sink());

  void log(String logger, Level level, String message, {Object? error}) {
    forwardToSentry(LogRecord(level, message, logger, error, StackTrace.current), logger: sink);
  }

  test('an allowlisted logger reaches Sentry Logs at its level, with its name', () {
    log('Sqlite', .WARNING, 'Skipped 2 workout row(s) this build cannot read');

    expect(sink.sent, [('warn', 'Skipped 2 workout row(s) this build cannot read', 'Sqlite')]);
  });

  test('levels map onto Sentry levels', () {
    log('Watch', .INFO, 'i');
    log('Watch', .WARNING, 'w');
    log('Watch', .SEVERE, 's');
    log('Watch', .SHOUT, 'f');

    expect(sink.sent.map((each) => each.$1), ['info', 'warn', 'error', 'fatal']);
  });

  test('the Health logger never leaves the device', () {
    log('Health', .SEVERE, 'Health read failed', error: Exception('heart rate 142'));

    expect(sink.sent, isEmpty);
  });

  test('a logger nobody has read is not forwarded', () {
    log('SomethingNew', .SEVERE, 'anything');

    expect(sink.sent, isEmpty);
  });

  test('fine-grained records stay on the device', () {
    log('Sqlite', .FINE, 'chatter');

    expect(sink.sent, isEmpty);
  });

  test('only the message goes, never the attached error', () {
    log('Sqlite', .SEVERE, 'Error migrating local db from version 17 to 18', error: Exception('INSERT ... [142]'));

    expect(sink.sent.single.$2, 'Error migrating local db from version 17 to 18');
    expect(sink.sent.single.$2, isNot(contains('142')));
  });
}

class _Sink implements SentryLogger {
  final sent = <(String, String, String?)>[];

  FutureOr<void> _add(String level, String body, Map<String, SentryAttribute>? attributes) {
    sent.add((level, body, attributes?['logger']?.value as String?));
  }

  @override
  FutureOr<void> trace(String body, {Map<String, SentryAttribute>? attributes}) => _add('trace', body, attributes);

  @override
  FutureOr<void> debug(String body, {Map<String, SentryAttribute>? attributes}) => _add('debug', body, attributes);

  @override
  FutureOr<void> info(String body, {Map<String, SentryAttribute>? attributes}) => _add('info', body, attributes);

  @override
  FutureOr<void> warn(String body, {Map<String, SentryAttribute>? attributes}) => _add('warn', body, attributes);

  @override
  FutureOr<void> error(String body, {Map<String, SentryAttribute>? attributes}) => _add('error', body, attributes);

  @override
  FutureOr<void> fatal(String body, {Map<String, SentryAttribute>? attributes}) => _add('fatal', body, attributes);

  @override
  SentryLoggerFormatter get fmt => throw UnimplementedError();
}
