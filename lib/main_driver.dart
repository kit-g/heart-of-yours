import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoNavigationBarBackButton;
// `flutter_driver` is a dev_dependency on purpose. The lint guards published
// packages, whose consumers do not get dev_dependencies — nothing depends on
// this app, and keeping it out of `dependencies` keeps webdriver and friends
// off the release resolution. `flutter_test` likewise, for the finders below.
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/flutter_driver.dart' show ByTooltipMessage, PageBack, SerializableFinder;
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart' show Finder, find;
import 'package:material_ui/material_ui.dart' show Tooltip;

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
  enableFlutterDriverExtension(finders: [_ByTooltipMessage(), _PageBack()]);
  return app.main();
}

// flutter_driver's own `ByTooltipMessage` and `PageBack` match
// flutter/material.dart's Tooltip and flutter/cupertino.dart's back button.
// This app builds on material_ui and cupertino_ui, whose types those never
// match: both finders would find nothing, and every script tapping an
// IconButton by its tooltip would time out. Registered under the same names,
// these win, so drivers keep sending the finders they always did.

class _ByTooltipMessage extends FinderExtension {
  @override
  String get finderType => 'ByTooltipMessage';

  @override
  SerializableFinder deserialize(Map<String, String> params, DeserializeFinderFactory finderFactory) {
    return ByTooltipMessage.deserialize(params);
  }

  @override
  Finder createFinder(SerializableFinder finder, CreateFinderFactory finderFactory) {
    final ByTooltipMessage(:text) = finder as ByTooltipMessage;
    return find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == text,
      description: 'widget with text tooltip "$text"',
    );
  }
}

class _PageBack extends FinderExtension {
  @override
  String get finderType => 'PageBack';

  @override
  SerializableFinder deserialize(Map<String, String> params, DeserializeFinderFactory finderFactory) {
    return const PageBack();
  }

  @override
  Finder createFinder(SerializableFinder finder, CreateFinderFactory finderFactory) {
    return find.byWidgetPredicate(
      (widget) => switch (widget) {
        Tooltip(message: 'Back') => true,
        CupertinoNavigationBarBackButton() => true,
        _ => false,
      },
      description: 'Material or Cupertino back button',
    );
  }
}
