part of 'settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final L(:settings, :appearance, :aboutApp, :notificationSettings) = L.of(context);
    final ThemeData(
      :textTheme,
      colorScheme: ColorScheme(:brightness, secondaryContainer: logoColor),
    ) = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: switch (brightness) {
          Brightness.dark => Brightness.light,
          Brightness.light => Brightness.dark,
        },
        statusBarBrightness: brightness,
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
          body: ListView(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      logoColor.withValues(alpha: .2),
                      logoColor,
                    ],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LogoTitle(fontSize: 32),
                      Motto(fontSize: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  appearance,
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: _ThemeModePicker(),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: _ColorPicker(),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(aboutApp),
                onTap: () {
                  final info = AppInfo.of(context);

                  showAboutDialog(
                    context: context,
                    applicationVersion: info.fullVersion,
                    applicationName: info.appName,
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_notifications_outlined),
                title: Text(notificationSettings),
                onTap: () {
                  //
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
