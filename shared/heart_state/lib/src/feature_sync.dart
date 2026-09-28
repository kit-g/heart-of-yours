import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:heart_models/heart_models.dart';

import 'features.dart';
import 'preferences.dart';

/// What [FeatureSync] needs of the session: who is signed in, whether that is
/// an account at all, and a way to write its settings. [Auth] is the one the
/// app has.
abstract interface class SettingsAccount implements Listenable {
  User? get user;

  bool get isAnonymous;

  /// Writes the account's settings; returns what the account then holds, or
  /// null when there is no account to write to.
  Future<Settings?> saveSettings(Settings settings);
}

/// Keeps a signed-in account's opt-in answers (#138) the same on every device
/// it is used on.
///
/// The device's [Preferences] stay the store the app reads; the account's
/// [Settings] carry a copy (`extra.features`, see [featureRecordsOf]). Each
/// answer carries when it was given, and whenever either side changes — the
/// account arriving at sign-in, or an answer given here — the later answer
/// wins on both: an older one here is replaced, an older one there is written
/// over. Nothing is ever deleted, on either side.
///
/// An anonymous session has no account to follow, so its answers stay on the
/// device until it becomes one — at which point they are the newer side and
/// go up.
class FeatureSync {
  final Preferences _preferences;
  final SettingsAccount _auth;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({
    required this._preferences,
    required this._auth,
    this.onError,
  }) {
    _preferences.addListener(_reconcile);
    _auth.addListener(_reconcile);
    _reconcile();
  }

  void dispose() {
    _preferences.removeListener(_reconcile);
    _auth.removeListener(_reconcile);
  }

  /// A write is out; another change meanwhile is picked up when it lands.
  bool _busy = false;
  bool _again = false;

  void _reconcile() {
    if (_busy) {
      _again = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    final user = _auth.user;
    // before the store is read there is nothing to compare, and adopting into
    // it would write nowhere and notify straight back here
    if (user == null || _auth.isAnonymous || !_preferences.isInitialized) return;

    _busy = true;
    try {
      final remote = featureRecordsOf(user.settings);
      final local = _preferences.featureRecords;

      final newerThere = {
        for (final MapEntry(key: feature, value: theirs) in remote.entries)
          if (local[feature] case final mine when mine == null || theirs.at.isAfter(mine.at)) feature: theirs,
      };
      final newerHere = {
        for (final MapEntry(key: feature, value: mine) in local.entries)
          if (remote[feature] case final theirs when theirs == null || mine.at.isAfter(theirs.at)) feature: mine,
      };

      // adopting notifies, which lands back here — as a no-op, since the two
      // sides then agree on everything adopted
      _preferences.adoptFeatureRecords(newerThere);
      if (newerHere.isNotEmpty) {
        await _auth.saveSettings(withFeatureRecords(user.settings, newerHere));
      }
    } catch (error, stacktrace) {
      // the device keeps its answer; the next change or sign-in tries again
      onError?.call(error, stacktrace: stacktrace);
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        _reconcile();
      }
    }
  }
}
