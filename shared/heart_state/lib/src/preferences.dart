import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseColor = 'baseColor';
const _themeMode = 'themeMode';
const _weightUnit = 'weightUnit';
const _distanceUnit = 'distanceUnit';

class Preferences with ChangeNotifier implements SignOutStateSentry {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  late MeasurementUnit _weight;

  late MeasurementUnit _distance;

  MeasurementUnit get weightUnit => _weight;

  MeasurementUnit get distanceUnit => _distance;

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

  Future<void> init({
    MeasurementUnit defaultWeightUnit = MeasurementUnit.metric,
    MeasurementUnit defaultDistanceUnit = MeasurementUnit.metric,
  }) async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    _initMeasurementUnits(
      defaultWeightUnit: defaultWeightUnit,
      defaultDistanceUnit: defaultWeightUnit,
    );
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

  void _initMeasurementUnits({
    required MeasurementUnit defaultWeightUnit,
    required MeasurementUnit defaultDistanceUnit,
  }) {
    _weight = switch (_prefs?.getString(_weightUnit)) {
      String s => MeasurementUnit.fromString(s),
      null => defaultWeightUnit,
    };

    _distance = switch (_prefs?.getString(_distanceUnit)) {
      String s => MeasurementUnit.fromString(s),
      null => defaultDistanceUnit,
    };
  }

  Future<bool>? setWeightUnit(MeasurementUnit unit) {
    _weight = unit;
    notifyListeners();
    return _prefs?.setString(_weightUnit, unit.name);
  }

  Future<bool>? setDistanceUnit(MeasurementUnit unit) {
    _distance = unit;
    notifyListeners();
    return _prefs?.setString(_distanceUnit, unit.name);
  }

  String distance(num value) {
    final v = distanceValue(value);
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  double distanceValue(num value) {
    return switch (distanceUnit) {
      MeasurementUnit.imperial => value.asMiles,
      MeasurementUnit.metric => value.toDouble(),
    };
  }

  String weight(num value) {
    final v = weightValue(value);
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  double weightValue(num value) {
    return switch (weightUnit) {
      MeasurementUnit.imperial => value.asPounds,
      MeasurementUnit.metric => value.toDouble(),
    };
  }
}
