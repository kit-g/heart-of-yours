part of 'settings.dart';

class SettingsPage extends StatelessWidget with HasHaptic {
  final VoidCallback onAccountManagement;
  final VoidCallback onImportData;

  const new({
    super.key,
    required this.onAccountManagement,
    required this.onImportData,
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
      :importData,
      :yourData,
      :account,
      :app,
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
              _Section(
                title: appearance,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: _ThemeModePicker(),
                  ),
                  SizedBox(height: 16),
                  // no page padding: the swatch strip scrolls to the screen
                  // edge and carries the inset itself
                  _PresetPicker(),
                ],
              ),
              const SizedBox(height: 24),
              _Section(
                title: units,
                children: [
                  // Preferences loads from disk without being awaited at startup,
                  // and its unit fields are `late` — reading one before
                  // [Preferences.isInitialized] throws (same hazard as
                  // goals/row.dart), so both pickers hold back until it lands;
                  // the Selector brings us straight back when it does.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Selector<Preferences, MeasurementUnit?>(
                      selector: (_, provider) => switch (provider.isInitialized) {
                        true => provider.weightUnit,
                        false => null,
                      },
                      builder: (_, weight, _) {
                        return switch (weight) {
                          null => const SizedBox.shrink(),
                          MeasurementUnit value => FixedLengthSettingPicker<MeasurementUnit>(
                            title: weightUnit,
                            value: value,
                            onValueChanged: (unit) {
                              buzz();
                              if (unit != null) {
                                Preferences.of(context).setWeightUnit(unit);
                              }
                            },
                            children: {
                              .imperial: Text(imperial),
                              .metric: Text(metric),
                            },
                          ),
                        };
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Selector<Preferences, MeasurementUnit?>(
                      selector: (_, provider) => switch (provider.isInitialized) {
                        true => provider.distanceUnit,
                        false => null,
                      },
                      builder: (_, distance, _) {
                        return switch (distance) {
                          null => const SizedBox.shrink(),
                          MeasurementUnit value => FixedLengthSettingPicker<MeasurementUnit>(
                            title: distanceUnit,
                            value: value,
                            onValueChanged: (unit) {
                              buzz();
                              if (unit != null) {
                                Preferences.of(context).setDistanceUnit(unit);
                              }
                            },
                            children: {
                              .imperial: Text(imperial),
                              .metric: Text(metric),
                            },
                          ),
                        };
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // owns its own header — the whole block is absent on platforms
              // with no health store, and a header over nothing would lie
              const HealthSettings(),
              const SizedBox(height: 24),
              _Section(
                title: yourData,
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_rounded),
                    title: Text(importData),
                    onTap: onImportData,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Section(
                title: account,
                children: [
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_rounded),
                    title: Text(accountControl),
                    onTap: onAccountManagement,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Section(
                title: app,
                children: [
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
              const SizedBox(height: 24),
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
        Api.instance
            .submitFeedback(
              feedback: feedback.text,
              screenshot: feedback.screenshot,
              mimeType: 'image/jpg',
            )
            .then(
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

/// A titled group of settings rows.
///
/// The title is a real header to assistive tech, so a screen reader can jump
/// section to section instead of row by row.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const new({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
