import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseColor = 'baseColor';
const _themeMode = 'themeMode';
const _weightUnit = 'weightUnit';
const _distanceUnit = 'distanceUnit';

class Preferences with ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  late MeasurementUnit _weight;

  late MeasurementUnit _distance;

  MeasurementUnit get weightUnit => _weight;

  MeasurementUnit get distanceUnit => _distance;

  static Preferences of(BuildContext context) {
    return Provider.of<Preferences>(context, listen: false);
  }

  static Preferences watch(BuildContext context) {
    return Provider.of<Preferences>(context, listen: true);
  }

  Future<void> init({Locale? locale}) async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    final unit = defaultUnit(locale?.countryCode);
    _initMeasurementUnits(
      defaultWeightUnit: unit,
      defaultDistanceUnit: unit,
    );
    notifyListeners();
  }

  MeasurementUnit defaultUnit(String? countryCode) {
    if (_imperialCountries.contains(countryCode)) {
      return .imperial;
    }
    return .metric;
  }

  Future<bool>? setBaseColor(String? userId, String? hex) {
    if (userId == null) return null;
    final key = '$_baseColor-$userId';
    if (hex == null) {
      return _prefs?.remove(key);
    }
    return _prefs?.setString(key, hex);
  }

  String? getBaseColor(String? userId) {
    if (userId == null) return null;
    return _prefs?.getString('$_baseColor-$userId');
  }

  Future<bool>? setThemeMode(ThemeMode? mode) {
    return switch (mode?.name) {
      String name => _prefs?.setString(_themeMode, name),
      null => _prefs?.remove(_themeMode),
    };
  }

  String? get themeMode {
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

  String distance(num value, {bool rounded = true}) {
    final v = distanceValue(value);
    return rounded ? v.rounded() : v.toString();
  }

  double distanceValue(num value) {
    return switch (distanceUnit) {
      .imperial => value.asMiles,
      .metric => value.toDouble(),
    };
  }

  String weight(num value, {bool rounded = true}) {
    final v = weightValue(value);
    return rounded ? v.rounded() : v.toString();
  }

  double weightValue(num value) {
    return switch (weightUnit) {
      .imperial => value.asPounds,
      .metric => value.toDouble(),
    };
  }
}

const _imperialCountries = {
  'US', // USA
  'LR', // Liberia
  'MM', // Myanmar
};

extension on num {
  String rounded() {
    if (this % 1 == 0) return toInt().toString();
    return toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
