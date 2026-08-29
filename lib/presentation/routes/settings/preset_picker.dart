part of 'settings.dart';

class _PresetPicker extends StatefulWidget {
  const new();

  @override
  State<_PresetPicker> createState() => _PresetPickerState();
}

class _PresetPickerState extends State<_PresetPicker> with HasHaptic<_PresetPicker> {
  @override
  Widget build(BuildContext context) {
    final L(:themePresetSetting, :themePresetSettingSubtitle) = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              themePresetSetting,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              themePresetSettingSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Consumer<AppTheme>(
          builder: (context, theme, _) {
            return Row(
              spacing: 12,
              children: [
                for (final preset in Preset.values)
                  _PresetSwatch(
                    preset: preset,
                    selected: theme.preset == preset,
                    onPressed: () {
                      buzz();
                      final auth = Auth.of(context);
                      theme.preset = preset;
                      Preferences.of(context).setBaseColor(auth.user?.id, preset.name);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  final Preset preset;
  final bool selected;
  final VoidCallback onPressed;

  const new({required this.preset, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final label = switch (preset) {
      .forge => L.of(context).themePresetForge,
      .ink => L.of(context).themePresetInk,
      .utility => L.of(context).themePresetUtility,
    };
    // Each half shows the preset in one brightness — its ground with its
    // accent sitting on it — so the swatch is the theme in miniature.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Column(
          spacing: 4,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const .all(.circular(8)),
                border: .all(
                  color: selected ? colorScheme.tertiary : colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: SizedBox(
                width: 96,
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  // clipped a step inside the frame so the halves' corners
                  // follow the rounding instead of poking into it
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                    child: Row(
                      children: [
                        Expanded(child: _half(preset.light)),
                        Expanded(child: _half(preset.dark)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Text(
              label,
              style: switch (selected) {
                true => textTheme.bodySmall?.copyWith(color: colorScheme.tertiary, fontWeight: .w600),
                false => textTheme.bodySmall,
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _half(Tokens tokens) {
    return ColoredBox(
      color: tokens.ground,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: .circle,
            color: tokens.accent,
            border: .all(color: tokens.border),
          ),
          child: const SizedBox.square(dimension: 18),
        ),
      ),
    );
  }
}
