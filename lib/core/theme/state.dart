import 'dart:math' show pow, sqrt;

import 'package:flutter/material.dart';
import 'package:heart_state/heart_state.dart';

class AppTheme with ChangeNotifier {
  ThemeMode _mode;

  Color? _color;

  Color? get color => _color;

  set color(Color? value) {
    _color = value;
    notifyListeners();
  }

  AppTheme({ThemeMode? mode}) : _mode = mode ?? ThemeMode.system;

  static AppTheme of(BuildContext context) {
    return Provider.of<AppTheme>(context, listen: false);
  }

  static AppTheme watch(BuildContext context) {
    return Provider.of<AppTheme>(context, listen: true);
  }

  ThemeMode get mode => _mode;

  void toLight() {
    _mode = ThemeMode.light;
    notifyListeners();
  }

  void toDark() {
    _mode = ThemeMode.dark;
    notifyListeners();
  }

  void toSystem() {
    _mode = ThemeMode.system;
    notifyListeners();
  }

  void toMode(String? v) {
    return switch (v) {
      'dark' => toDark(),
      'light' => toLight(),
      'system' => toSystem(),
      _ => () {},
    };
  }

  static Color? colorFromHex(String? hex) {
    try {
      final buffer = StringBuffer();
      if (hex!.length == 6 || hex.length == 7) {
        buffer.write('FF');
      }
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  String heart() {
    return switch (color) {
      Color seed => _coloredEmoji(seed),
      null => '💜',
    };
  }
}

String _coloredEmoji(Color seedColor) {
  return _heartColors.entries.reduce(
    (a, b) {
      final aDistance = _distance(seedColor, a.value);
      final bDistance = _distance(seedColor, b.value);
      return aDistance < bDistance ? a : b;
    },
  ).key;
}

double _distance(Color a, Color b) {
  return sqrt(
    pow(a.r - b.r, 2) + pow(a.g - b.g, 2) + pow(a.b - b.b, 2),
  );
}

const _heartColors = {
  '❤️': Color(0xFFFF0000), // Red
  '🧡': Color(0xFFFFA500), // Orange
  '💛': Color(0xFFFFFF00), // Yellow
  '💚': Color(0xFF00FF00), // Green
  '💙': Color(0xFF0000FF), // Blue
  '💜': Color(0xFF800080), // Purple
  '🖤': Color(0xFF000000), // Black
  '🤍': Color(0xFFFFFFFF), // White
  '🤎': Color(0xFF8B4513), // Brown
};
