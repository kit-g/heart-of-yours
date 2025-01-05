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
}
