import 'package:logging/logging.dart';

void initLogging(String level) {
  Logger.root.level = _getLevel(level);
  Logger.root.onRecord.listen(_log);
}

Level _getLevel(String v) {
  return switch (v) {
    'ALL' => Level.ALL,
    _ => Level.OFF,
  };
}

void _log(LogRecord record) {
  // ignore: avoid_print
  print('${record.level.name}: ${record.time}: ${record.message}');
}
