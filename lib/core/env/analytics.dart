import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:heart/core/env/telemetry.dart';
import 'package:heart_state/heart_state.dart';

/// Writes [Analytics]' events to Firebase.
///
/// The only file in the app that knows the SDK exists; everything upstream
/// speaks `AnalyticsService`, which is what lets a run that must not report
/// swap the transport rather than guard every call site.
class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics;

  new({FirebaseAnalytics? analytics}) : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserProperty(String name, String? value) {
    return _analytics.setUserProperty(name: name, value: value);
  }
}

/// Drops everything it is given.
///
/// What a debug build, the driver and Test Lab get. Not a null `Analytics`:
/// the call sites stay identical in every run, so a reporting bug cannot hide
/// behind a branch that only production takes.
class const SilentAnalyticsService() implements AnalyticsService {
  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

/// The transport for this run, and the SDK's own collection switched to match.
///
/// Both halves matter. Returning [SilentAnalyticsService] stops the events this
/// app sends; `setAnalyticsCollectionEnabled` stops the ones the SDK sends by
/// itself — `screen_view` above all, which `FirebaseAnalyticsObserver` fires on
/// every route change. Without the second half a `flutter_driver` run still
/// reports a session's worth of navigation, and the funnels this exists to
/// measure are counted against a robot.
///
/// Firebase must be initialized first: this touches `FirebaseAnalytics.instance`.
Future<AnalyticsService> initAnalytics() async {
  final reports = (!kDebugMode || forceTelemetry) && !await excludedFromTelemetry();
  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(reports);
  } catch (_) {
    // The same rule the events themselves follow: a launch that would
    // otherwise work must not fail because reporting could not be set up.
    // Silent is the safe reading of a half-built SDK — better to lose a
    // session's events than to send them somewhere unknown.
    return const SilentAnalyticsService();
  }
  return switch (reports) {
    true => FirebaseAnalyticsService(),
    false => const SilentAnalyticsService(),
  };
}
