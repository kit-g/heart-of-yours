import 'utils.dart';

abstract mixin class UsesTimestampForId implements Comparable<UsesTimestampForId> {
  DateTime get start;

  /// Firebase uses "." as the separator for nested structures
  /// so we need to escape it.
  String get id => sanitizeId(start);

  @override
  bool operator ==(Object other) {
    return other is UsesTimestampForId && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Duration elapsed() => DateTime.now().difference(start);

  @override
  int compareTo(covariant UsesTimestampForId other) {
    return start.compareTo(other.start);
  }
}

