/// Selects a [HealthService] implementation at compile time.
///
/// The `health` plugin imports `dart:io` and ships only iOS and Android
/// implementations, so merely importing it breaks the web build. Web therefore
/// resolves to [UnsupportedHealthStore], which pulls in nothing.
///
/// Everywhere `dart:io` exists — including macOS and desktop, where the plugin
/// compiles but has no native side — resolves to the real store, which then
/// checks the platform at runtime and degrades to unsupported itself.
library;

export 'stub.dart' if (dart.library.io) 'device.dart';
