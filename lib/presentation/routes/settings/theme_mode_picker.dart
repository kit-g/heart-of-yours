part of 'settings.dart';

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context) {
    final L(:toDarkMode, :toLightMode, :toSystemMode) = L.of(context);
    return Consumer<AppTheme>(
      builder: (__, appTheme, _) {
        final isSelected = ThemeMode.values.map((mode) => mode == appTheme.mode).toList();
        const radius = 4.0;
        return SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) {
              return ToggleButtons(
                constraints: BoxConstraints.expand(
                  width: (box.maxWidth - radius) / 3,
                ),
                borderRadius: BorderRadius.circular(radius),
                isSelected: isSelected,
                onPressed: (index) => _onPressed(context, index, appTheme),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_suggest_rounded),
                        const SizedBox(width: 4),
                        Text(toSystemMode),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded),
                        const SizedBox(width: 4),
                        Text(toLightMode),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.nights_stay_rounded),
                        const SizedBox(width: 4),
                        Text(toDarkMode),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _onPressed(BuildContext context, int index, AppTheme appTheme) {
    switch (index) {
      case 0:
        Preferences.of(context).setThemeMode(ThemeMode.system);
      case 1:
        Preferences.of(context).setThemeMode(ThemeMode.light);
      case 2:
        Preferences.of(context).setThemeMode(ThemeMode.dark);
    }
    return switch (index) {
      0 => appTheme.toSystem(),
      1 => appTheme.toLight(),
      2 => appTheme.toDark(),
      _ => () {},
    };
  }
}
