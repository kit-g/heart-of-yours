part of 'settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L(:settings, :appearance) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: switch (colorScheme.brightness) {
          Brightness.dark => Brightness.light,
          Brightness.light => Brightness.dark,
        },
        statusBarBrightness: colorScheme.brightness,
      ),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Stack(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(settings),
                    const SizedBox(width: 8),
                    const Icon(Icons.settings_rounded),
                  ],
                ),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ListView(
              children: [
                Text(
                  appearance,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const _ThemeModePicker(),
                const SizedBox(height: 16),
                const _ColorPicker(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
