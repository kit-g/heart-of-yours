import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class RemoteConfig implements SignOutStateSentry {
  final RemoteConfigService _service;
  final _config = <String, dynamic>{};
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  bool isInitialized = false;

  RemoteConfig({
    required RemoteConfigService service,
    this.onError,
  }) : _service = service;

  Future<void> init() async {
    if (isInitialized) return;
    isInitialized = true;
    try {
      final config = await _service.getRemoteConfig();
      _config.addAll(config.map((key, value) => MapEntry(key, value.toString())));
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      isInitialized = false;
    }
  }

  @override
  void onSignOut() {
    _config.clear();
  }

  static RemoteConfig of(BuildContext context) {
    return Provider.of<RemoteConfig>(context, listen: false);
  }

  static RemoteConfig watch(BuildContext context) {
    return Provider.of<RemoteConfig>(context, listen: true);
  }

  DateTime? get exercisesLastSynced => DateTime.tryParse(_config['exercisesLastSynced'] ?? '');
}
