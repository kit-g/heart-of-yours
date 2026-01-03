part of 'settings.dart';

class SettingsPage extends StatelessWidget with HasHaptic {
  final VoidCallback onAccountManagement;

  const SettingsPage({
    super.key,
    required this.onAccountManagement,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      :aboutApp,
      :accountControl,
      :appearance,
      :distanceUnit,
      :imperial,
      :metric,
      :notificationSettings,
      :settings,
      :units,
      :weightUnit,
      :leaveFeedback,
      :cancel,
      :toFeedback,
      :leaveFeedbackBody,
    ) = L.of(
      context,
    );

    final ThemeData(
      :textTheme,
      colorScheme: ColorScheme(
        :brightness,
        secondaryContainer: logoColor,
        :outlineVariant,
        :primaryContainer,
        :onPrimaryContainer,
        :primary,
      ),
    ) = Theme.of(
      context,
    );

    final heart = AppTheme.of(context).heart();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: switch (brightness) {
          .dark => .light,
          .light => .dark,
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
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: LogoStripe(),
            ),
          ),
          body: ListView(
            children: [
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
                  builder: (_, weight, _) {
                    return FixedLengthSettingPicker<MeasurementUnit>(
                      title: weightUnit,
                      value: weight,
                      onValueChanged: (unit) {
                        buzz();
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
                  builder: (_, distance, _) {
                    return FixedLengthSettingPicker<MeasurementUnit>(
                      title: distanceUnit,
                      value: distance,
                      onValueChanged: (unit) {
                        buzz();
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
                    applicationName: AppConfig.of(context).appName,
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.manage_accounts_rounded),
                title: Text(accountControl),
                onTap: onAccountManagement,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.feedback_rounded),
                title: Text('$leaveFeedback $heart'),
                onTap: () {
                  showBrandedDialog(
                    context,
                    title: Text(leaveFeedback),
                    titleTextStyle: textTheme.titleMedium,
                    icon: Icon(
                      Icons.feedback_rounded,
                      color: onPrimaryContainer,
                    ),
                    content: Text(
                      leaveFeedbackBody(AppTheme.of(context).heart()),
                      textAlign: TextAlign.center,
                    ),
                    actions: [
                      PrimaryButton.wide(
                        backgroundColor: outlineVariant.withValues(alpha: .5),
                        child: Center(
                          child: Text(cancel),
                        ),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton.wide(
                        backgroundColor: primaryContainer,
                        child: Center(
                          child: Text(toFeedback),
                        ),
                        onPressed: () => _openFeedback(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFeedback(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
    final L(:feedbackReceived) = L.of(context);
    final heart = AppTheme.of(context).heart();

    final messenger = ScaffoldMessenger.of(context);

    BetterFeedback.of(context).show(
      (feedback) {
        Api.instance.submitFeedback(feedback: feedback.text, screenshot: feedback.screenshot).then(
          (success) {
            if (success) {
              messenger.showSnackBar(
                SnackBar(content: Text('$feedbackReceived $heart')),
              );
            }
          },
        );
      },
    );
  }
}
