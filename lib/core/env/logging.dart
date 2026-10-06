import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

extension on LogRecord {
  String toLine() {
    final buffer = StringBuffer()..write('[$loggerName]: ${level.name} - $message');
    if (error != null) {
      buffer.write('\n\x1B[31mError: $error\x1B[0m');
    }

    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }

    return buffer.toString();
  }

  // ignore: avoid_print
  void write() => print(toLine());
}

/// Routes the `logging` package's records: printed in a debug build, and from
/// the loggers in [forwardedLoggers] sent to Sentry Logs in any build that
/// runs Sentry. A release build prints nothing — a device console is read by
/// no one and costs every line — so what used to be switched off there now
/// reaches someone.
void initLogging(String level) {
  Logger.root
    ..level = _getLevel(level)
    ..onRecord.listen((record) {
      if (kDebugMode) record.write();
      forwardToSentry(record);
    });
}

Level _getLevel(String v) {
  return switch (v) {
    'ALL' => .ALL,
    _ => kDebugMode ? .ALL : .INFO,
  };
}

/// The loggers whose lines go to Sentry Logs: an allowlist, so a logger added
/// later stays on the device until someone has read what it says.
///
/// Never `Health`: health data is device-only, and its records carry the
/// platform's errors, which can echo the very readings they failed on (see
/// `reportHealthFailure` and `docs/2026-09-05.health-data.md`).
@visibleForTesting
const forwardedLoggers = {'Sqlite', 'Notifications', 'OngoingWorkout', 'Watch', 'Router'};

/// Sends [record] to Sentry Logs: its message, level and logger, and nothing
/// else. Never the attached error or stack trace — an error goes to Sentry as
/// an issue through `reportToSentry`, and its text (a database error's SQL and
/// bound values, say) is exactly what a log line must not carry. Fine-grained
/// records stay on the device. A no-op until Sentry is initialized.
@visibleForTesting
void forwardToSentry(LogRecord record, {SentryLogger? logger}) {
  if (!forwardedLoggers.contains(record.loggerName) || record.level < Level.INFO) return;

  final sink = logger ?? Sentry.logger;
  final attributes = {'logger': SentryAttribute.string(record.loggerName)};
  final sent = switch (record.level) {
    >= Level.SHOUT => sink.fatal(record.message, attributes: attributes),
    >= Level.SEVERE => sink.error(record.message, attributes: attributes),
    >= Level.WARNING => sink.warn(record.message, attributes: attributes),
    _ => sink.info(record.message, attributes: attributes),
  };
  unawaited(Future.value(sent));
}

typedef LogInit = void Function(String level);
