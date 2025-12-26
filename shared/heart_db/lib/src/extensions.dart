part of '../heart_db.dart';

extension on String {
  /// converts a snake_case string to camelCase
  String toCamel() {
    final words = this.split('_');
    return words.first + words.skip(1).map((word) => word[0].toUpperCase() + word.substring(1)).join();
  }

  /// converts a camelCase string to snake_case
  String toSnake() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]}_${match[2]}').toLowerCase();
  }
}

extension on Map<String, dynamic> {
  /// converts every key in this to camelCase,
  /// expecting it to be in snake_case initially
  Map<String, dynamic> toCamel() {
    return {
      for (final MapEntry(:key, :value) in entries) key.toCamel(): value,
    };
  }
}

extension on Map {
  Map toWorkout() {
    return map(
      (key, value) {
        return switch (key) {
          'exercises' => MapEntry(key, jsonDecode(value)),
          'image' when value != null => MapEntry(key, jsonDecode(value)),
          'end' => MapEntry(key, value ?? ''),
          _ => MapEntry(key, value),
        };
      },
    );
  }
}

extension on DatabaseExecutor {
  Future<int> getMaxValue(String table, String column) async {
    final rows = await rawQuery('SELECT max($column) AS max_value FROM $table;');
    return switch (rows) {
      [{'max_value': num v}] => v.toInt(),
      _ => 0,
    };
  }
}

