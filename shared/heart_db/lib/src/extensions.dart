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

/// Sentinel order for exercise rows written before `exercise_order` was
/// populated. Sorts them after every ordered row, keeping their relative
/// position among themselves.
const _unordered = 1 << 31;

int _orderOf(dynamic exercise) {
  return switch (exercise) {
    {'order': int order} => order,
    _ => _unordered,
  };
}

/// `json_group_array` makes no promise about the order of its elements, so the
/// exercises of a workout come back in whatever order SQLite happened to emit
/// rows in. Sort them by the stored `exercise_order` — the user's own ordering,
/// which for the active workout lives nowhere else until the workout is
/// finished and pushed to the server.
///
/// [List.sort] is not stable, so ties fall back to the original position.
List<dynamic> _ordered(dynamic decoded) {
  if (decoded is! List) return const [];
  final indexed = decoded.indexed.toList()
    ..sort(
      (one, two) {
        return switch (_orderOf(one.$2).compareTo(_orderOf(two.$2))) {
          0 => one.$1.compareTo(two.$1),
          int byOrder => byOrder,
        };
      },
    );
  return indexed.map((each) => each.$2).toList();
}

extension on Map {
  Map toWorkout() {
    return map(
      (key, value) {
        return switch (key) {
          'exercises' => MapEntry(key, _ordered(jsonDecode(value))),
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
