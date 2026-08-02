import 'package:heart_health/heart_health.dart';

/// The store a platform with no `dart:io` can offer — web, always nothing.
///
/// Mirrors the signature of its counterpart in `device.dart` so the conditional
/// export in `store.dart` presents one API to callers. This file exists to keep
/// `package:health` — which imports `dart:io` and ships no web implementation —
/// out of the web build entirely.
HealthService healthStore() => const UnsupportedHealthStore();
