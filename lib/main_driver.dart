// `flutter_driver` is a dev_dependency on purpose. The lint guards published
// packages, whose consumers do not get dev_dependencies — nothing depends on
// this app, and keeping it out of `dependencies` keeps webdriver and friends
// off the release resolution.
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

/// Debug entrypoint that exposes the Flutter Driver extension, so a tool
/// attached over the VM service can tap, scroll and type in the running app:
///
///     flutter run -t lib/main_driver.dart
///
/// Deliberately not folded into [app.main] behind `kDebugMode`. The extension
/// is only worth anything while something is actually driving it, so this keeps
/// a plain `flutter run` untouched and leaves `flutter_driver` unreferenced from
/// the shipping entrypoint, where it is tree-shaken rather than merely dead.
///
/// No new attack surface in debug: the VM service is already open — that is how
/// hot reload works — and it exposes `evaluate`, which is strictly more powerful
/// than tapping a button. In release the VM service does not exist at all.
Future<void> main() {
  // must come before anything that touches a binding: this installs its own
  // (`_DriverBinding`), and constructing `WidgetsFlutterBinding` first leaves it
  // asserting "Binding is already initialized". `bootstrap` calling
  // `ensureInitialized` afterwards is fine — it returns the existing instance.
  enableFlutterDriverExtension();
  return app.main();
}
