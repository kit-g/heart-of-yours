import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Charts with ChangeNotifier, Iterable<ChartPreference> implements SignOutStateSentry {
  final _preferences = <ChartPreference>[];
  final ChartPreferenceService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  String? userId;

  Charts({
    required ChartPreferenceService service,
    this.onError,
  }) : _service = service;

  @override
  void onSignOut() {
    _preferences.clear();
  }

  @override
  Iterator<ChartPreference> get iterator => _preferences.iterator;

  ChartPreference operator [](int index) {
    return _preferences[index];
  }

  static Charts of(BuildContext context) {
    return Provider.of<Charts>(context, listen: false);
  }

  static Charts watch(BuildContext context) {
    return Provider.of<Charts>(context, listen: true);
  }

  Future<void> init() async {
    if (userId case String id) {
      await _service.getPreferences(id).then(_preferences.addAll);
      notifyListeners();
    }
  }

  Future<void> addPreference(ChartPreference preference) async {
    if (userId case String id) {
      final saved = await _service.saveChartPreference(preference, id);
      _preferences.add(saved);
      notifyListeners();
    }
  }

  Future<void> removePreference(ChartPreference preference) async {
    if (userId case String id) {
      if (preference.id case String preferenceId) {
        await _service.deleteChartPreference(preferenceId, id);
        _preferences.removeWhere((each) => each.id == preference.id);
        notifyListeners();
      }
    }
  }
}
