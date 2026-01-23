import 'package:logging/logging.dart';

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

void initLogging(String level) {
  Logger.root
    ..level = _getLevel(level)
    ..onRecord.listen((record) => record.write());
}

Level _getLevel(String v) {
  return switch (v) {
    'ALL' => Level.ALL,
    _ => Level.OFF,
  };
}

typedef LogInit = void Function(String level);
