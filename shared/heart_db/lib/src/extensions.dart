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
      for (var MapEntry(:key, :value) in entries) key.toCamel(): value,
    };
  }
}
