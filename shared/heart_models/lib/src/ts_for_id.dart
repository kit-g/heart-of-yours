abstract mixin class UsesTimestampForId {
  DateTime get start;

  String get id => start.toIso8601String();

  @override
  bool operator ==(Object other) {
    return other is UsesTimestampForId && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Duration elapsed() => DateTime.now().difference(start);
}
