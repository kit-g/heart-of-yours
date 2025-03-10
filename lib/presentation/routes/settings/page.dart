part of 'settings.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onAccountManagement;

  const SettingsPage({
    super.key,
    required this.onAccountManagement,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      :aboutApp,
      :accountManagement,
      :appearance,
      :distanceUnit,
      :imperial,
      :metric,
      :notificationSettings,
      :settings,
      :units,
      :weightUnit,
    ) = L.of(context);

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
              const LogoStripe(),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  units,
                  style: textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Selector<Preferences, MeasurementUnit>(
                  selector: (_, provider) => provider.weightUnit,
                  builder: (_, weight, __) {
                    return FixedLengthSettingPicker<MeasurementUnit>(
                      title: weightUnit,
                      value: weight,
                      onValueChanged: (unit) {
                        if (unit != null) {
                          Preferences.of(context).setWeightUnit(unit);
                        }
                      },
                      children: {
                        MeasurementUnit.imperial: Text(imperial),
                        MeasurementUnit.metric: Text(metric),
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Selector<Preferences, MeasurementUnit>(
                  selector: (_, provider) => provider.distanceUnit,
                  builder: (_, distance, __) {
                    return FixedLengthSettingPicker<MeasurementUnit>(
                      title: distanceUnit,
                      value: distance,
                      onValueChanged: (unit) {
                        if (unit != null) {
                          Preferences.of(context).setDistanceUnit(unit);
                        }
                      },
                      children: {
                        MeasurementUnit.imperial: Text(imperial),
                        MeasurementUnit.metric: Text(metric),
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<bool>(
                future: hasNotificationsPermission(Theme.of(context).platform),
                builder: (context, snapshot) {
                  return ListTile(
                    leading: switch (snapshot.hasData && (snapshot.data ?? false)) {
                      true => const Icon(Icons.edit_notifications_rounded),
                      false => const Icon(Icons.notifications_off_rounded),
                    },
                    title: Text(notificationSettings),
                    onTap: () {
                      AppSettings.openAppSettings(type: AppSettingsType.notification, asAnotherTask: true);
                    },
                  );
                },
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
                    applicationName: AppConfig.appName,
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.manage_accounts_rounded),
                title: Text(accountManagement),
                onTap: onAccountManagement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
