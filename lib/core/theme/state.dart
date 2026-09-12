import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class AppTheme with ChangeNotifier implements SignOutStateSentry {
  ThemeMode _mode;

  /// Ink, light-first, with the brightness left to the system — the house
  /// style, and what the marketing site is drawn in. A first launch should
  /// look like the thing that sold it.
  Preset _preset = .ink;

  Preset get preset => _preset;

  set preset(Preset value) {
    _preset = value;
    notifyListeners();
  }

  new({ThemeMode? mode}) : _mode = mode ?? ThemeMode.system;

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

  String heart() {
    return switch (_preset) {
      .forge => '💚',
      .ink => '💙',
      .utility => '🩶',
      .ember => '🧡',
    };
  }

  @override
  FutureOr<void> onSignOut() {
    _preset = .ink;
    _mode = ThemeMode.system;
  }
}
