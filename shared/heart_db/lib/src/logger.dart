part of '../heart_db.dart';

final _logger = Logger('Sqlite');

/// The rows this build can read, each through [parse], in order.
///
/// A row this build cannot read is one written by a newer build (an app
/// downgraded, or a database restored onto an older one) or synced down with a
/// value it has never heard of. It is left in the table untouched, for the
/// build that can read it, and costs only itself: one unreadable workout used
/// to take the whole history with it, and one exercise every workout joining it.
List<T> _readable<R, T>(Iterable<R> rows, T Function(R row) parse, {required String what}) {
  var skipped = 0;
  final read = <T>[];
  for (final row in rows) {
    try {
      read.add(parse(row));
    } catch (_) {
      skipped++;
    }
  }
  if (skipped > 0) _logger.warning('Skipped $skipped $what row(s) this build cannot read');
  return read;
}

/// One row through [parse], or null when this build cannot read it — the same
/// answer as no row at all. See [_readable].
T? _readOne<T>(T Function() parse, {required String what}) {
  try {
    return parse();
  } catch (_) {
    _logger.warning('Skipped a $what row this build cannot read');
    return null;
  }
}
