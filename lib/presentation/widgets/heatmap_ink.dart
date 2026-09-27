import 'dart:math';

import 'package:flutter/material.dart';

/// How many shades a heatmap cell can take, besides empty.
///
/// Stepped rather than continuous: with every step held to the contrast floor
/// the ramp is short, and four shades that can be told apart beat a smooth
/// run whose neighbours cannot.
const heatmapSteps = 4;

/// The contrast a filled cell and an empty week's mark keep against the panel
/// they sit on — WCAG 1.4.11's floor for graphics a reader needs.
const heatmapContrast = 3.0;

/// The shade of a cell holding [share] of the grid's largest value, on
/// [ground]: the accent ink, from the faintest alpha that still clears
/// [heatmapContrast] up to full, in [heatmapSteps] steps.
///
/// The floor is measured, not a constant: each preset's panel and accent sit
/// at different lightness, and one that passes on light Forge sinks on dark
/// Ink — measured, it was 1.05:1.
Color heatmapShade(ColorScheme scheme, Color ground, double share) {
  final floor = _floorAlpha(scheme.tertiary, ground);
  final step = max(1, (share.clamp(0, 1) * heatmapSteps).ceil());
  return scheme.tertiary.withValues(alpha: floor + (1 - floor) * (step - 1) / (heatmapSteps - 1));
}

/// What marks an empty week: not a fill, which at any strength that clears the
/// floor reads as "some", but a small dot in the muted ink.
Color heatmapEmpty(ColorScheme scheme) => scheme.outline;

/// The smallest alpha at which [ink] over [ground] clears [heatmapContrast].
double _floorAlpha(Color ink, Color ground) {
  double contrast(double alpha) {
    final blended = Color.alphaBlend(ink.withValues(alpha: alpha), ground).computeLuminance();
    final base = ground.computeLuminance();
    return (max(blended, base) + .05) / (min(blended, base) + .05);
  }

  // halving: contrast rises with alpha, and 1/256 is finer than a pixel shows
  var (low, high) = (0.0, 1.0);
  for (final _ in Iterable.generate(8)) {
    final mid = (low + high) / 2;
    switch (contrast(mid) >= heatmapContrast) {
      case true:
        high = mid;
      case false:
        low = mid;
    }
  }
  return high;
}
