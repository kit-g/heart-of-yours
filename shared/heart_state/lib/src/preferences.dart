import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseColor = 'baseColor';
const _themeMode = 'themeMode';

class Preferences with ChangeNotifier implements SignOutStateSentry {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  @override
  void onSignOut() {
    _prefs?.clear();
  }

  static Preferences of(BuildContext context) {
    return Provider.of<Preferences>(context, listen: false);
  }

  static Preferences watch(BuildContext context) {
    return Provider.of<Preferences>(context, listen: true);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool>? setBaseColor(String? hex) {
    if (hex == null) {
      return _prefs?.remove(_baseColor);
    }
    return _prefs?.setString(_baseColor, hex);
  }

  String? getBaseColor() {
    return _prefs?.getString(_baseColor);
  }

  Future<bool>? setThemeMode(ThemeMode? mode) {
    return switch (mode?.name) {
      String name => _prefs?.setString(_themeMode, name),
      null => _prefs?.remove(_themeMode),
    };
  }

  String? getThemeMode() {
    return _prefs?.getString(_themeMode);
  }
}
