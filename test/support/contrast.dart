import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// The WCAG contrast ratio between two colours, 1 to 21.
double contrast(Color one, Color two) {
  final (a, b) = (one.computeLuminance(), two.computeLuminance());
  return (max(a, b) + .05) / (min(a, b) + .05);
}
