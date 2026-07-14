import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Charts with ChangeNotifier, Iterable<ChartPreference> implements SignOutStateSentry {
  final _preferences = <ChartPreference>[];
  final ChartPreferenceService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  String? userId;
  bool initialized = false;
  Future<void>? _loading;

  Charts({
    required ChartPreferenceService service,
    this.onError,
  }) : _service = service;

  @override
  void onSignOut() {
    _preferences.clear();
    initialized = false;
    _loading = null;
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

  Future<void> init() {
    // idempotent: a completed init is a no-op, and concurrent callers share the
    // single in-flight load, so preferences are never appended twice
    return switch ((initialized, userId)) {
      (true, _) => Future.value(),
      (false, String id) => _loading ??= _load(id).whenComplete(() => _loading = null),
      (false, null) => Future.value(),
    };
  }

  Future<void> _load(String id) async {
    final preferences = await _service.getPreferences(id);
    _preferences
      ..clear()
      ..addAll(preferences);
    initialized = true;
    notifyListeners();
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
