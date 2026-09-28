import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

extension MaterialUiFinders on CommonFinders {
  /// `find.byTooltip`, for material_ui's [Tooltip].
  ///
  /// flutter_test's own matches flutter/material.dart's Tooltip, which this app
  /// no longer builds, so it finds nothing here — always.
  Finder tooltip(String message) {
    return byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == message,
      description: 'Tooltip "$message"',
    );
  }
}
