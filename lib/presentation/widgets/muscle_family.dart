import 'package:heart/core/theme/tokens.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

extension MuscleFamilyCopy on MuscleFamily {
  String label(L l) {
    return switch (this) {
      .chest => l.targetChest,
      .back => l.targetBack,
      .shoulders => l.targetShoulders,
      .arms => l.targetArms,
      .core => l.targetCore,
      .lowerBody => l.muscleFamilyLowerBody,
    };
  }
}

/// A muscle family's colour, as a dot (#617). Decoration: whatever it sits
/// beside says the family's name, so a screen reader skips the dot itself.
class FamilyDot extends StatelessWidget {
  final MuscleFamily family;
  final double size;

  /// Beside a choice that cannot be made: as greyed as its label.
  final bool enabled;

  const new(this.family, {super.key, this.size = 8, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: muscleFamilyColor(family, Theme.of(context).brightness).withValues(alpha: enabled ? 1 : 0.38),
            shape: .circle,
          ),
        ),
      ),
    );
  }
}

/// Every family with its colour, in a line that wraps (#617): the key to a
/// screen that marks things by family colour alone.
class FamilyLegend extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: .center,
      children: [
        for (final family in MuscleFamily.values)
          Row(
            mainAxisSize: .min,
            spacing: 4,
            children: [
              FamilyDot(family),
              Text(family.label(l), style: style),
            ],
          ),
      ],
    );
  }
}
