import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/presentation/widgets/heatmap_ink.dart';

/// The muscle map's heatmap (#136) on every preset, both brightnesses: each
/// shade and the empty-week mark keep WCAG 1.4.11's 3:1 against the panel,
/// and the shades still step darker (or, in dark mode, brighter) with the
/// count.
void main() {
  double contrast(Color a, Color b) {
    final (la, lb) = (a.computeLuminance(), b.computeLuminance());
    return (max(la, lb) + .05) / (min(la, lb) + .05);
  }

  for (final preset in Preset.values) {
    for (final tokens in [preset.light, preset.dark]) {
      final scheme = tokens.colorScheme();
      final panel = scheme.surfaceContainer;
      final name = '${preset.name} ${tokens.brightness.name}';

      test('$name: every shade clears 3:1 on the panel, and each is further from it than the last', () {
        final shades = [
          for (final step in Iterable<int>.generate(heatmapSteps, (index) => index + 1))
            Color.alphaBlend(heatmapShade(scheme, panel, step / heatmapSteps), panel),
        ];
        final contrasts = shades.map((shade) => contrast(shade, panel)).toList();

        expect(contrasts.first, greaterThanOrEqualTo(heatmapContrast));
        for (final (index, value) in contrasts.indexed.skip(1)) {
          expect(value, greaterThan(contrasts[index - 1]), reason: 'step ${index + 1}');
        }
      });

      test('$name: an empty week\'s mark clears 3:1 on the panel', () {
        expect(contrast(heatmapEmpty(scheme), panel), greaterThanOrEqualTo(heatmapContrast));
      });
    }
  }

  test('a share buckets into its step: the smallest non-zero share is the first, the largest the last', () {
    final scheme = Preset.values.first.light.colorScheme();
    final panel = scheme.surfaceContainer;
    Color shade(double share) => heatmapShade(scheme, panel, share);

    expect(shade(.01), shade(1 / heatmapSteps));
    expect(shade(1), scheme.tertiary.withValues(alpha: 1));
    expect(shade(.26), isNot(shade(.25)));
  });
}
