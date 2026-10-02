part of 'settings.dart';

/// Widest the settings list gets; beyond it the page centres it.
const _maxWidth = 640.0;

class SettingsPage extends StatelessWidget with HasHaptic {
  final VoidCallback onAccountManagement;
  final VoidCallback onImportData;
  final VoidCallback onExportData;
  final VoidCallback onWhatsNew;
  final VoidCallback onRestTimers;

  /// Where the app goes once an anonymous session's data is erased.
  final VoidCallback onErased;

  const new({
    super.key,
    required this.onAccountManagement,
    required this.onImportData,
    required this.onExportData,
    required this.onWhatsNew,
    required this.onRestTimers,
    required this.onErased,
  });

  @override
  Widget build(BuildContext context) {
    final L(
      :aboutApp,
      :whatsNew,
      :accountControl,
      :appearance,
      :distanceUnit,
      :imperial,
      :metric,
      :restTimers,
      :settings,
      :units,
      :weightUnit,
      :leaveFeedback,
      :cancel,
      :toFeedback,
      :leaveFeedbackBody,
      :importData,
      :exportData,
      :eraseData,
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
        :error,
      ),
    ) = Theme.of(
      context,
    );

    final heart = AppTheme.of(context).heart();
    // Import, feedback and the account itself all go through the server, so
    // they want an account. Absent rather than dead while the session is
    // anonymous — the profile's no-account dialog is the one place that says
    // why, and a row that fails on tap would only be a reminder in disguise.
    // The one row the anonymous session has instead is the erase: with no
    // account to delete, this is how everything the device holds goes.
    // Export is the row both sessions share: it reads the device, not the
    // server, so it owes nothing to an account.
    final isAnonymous = Auth.watch(context).isAnonymous;
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
          // Capped and centred: every row here is a label with its control
          // at the far edge, and on a landscape iPad that edge was 1100pt away
          // — a switch nobody would connect to its name. Padding rather than a
          // narrowed box, so the page still scrolls from its whole width.
          body: LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: .symmetric(horizontal: math.max(0, (constraints.maxWidth - _maxWidth) / 2)),
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
                const _FeaturesSection(),
                const SizedBox(height: 24),
                // owns its own header — the whole block is absent on platforms
                // with no health store, and a header over nothing would lie
                const HealthSettings(),
                const SizedBox(height: 24),
                _Section(
                  title: yourData,
                  children: [
                    if (!isAnonymous)
                      ListTile(
                        leading: const Icon(Icons.upload_file_rounded),
                        title: Text(importData),
                        onTap: onImportData,
                      ),
                    ListTile(
                      key: AppKeys.exportData,
                      leading: const Icon(Icons.file_download_rounded),
                      title: Text(exportData),
                      onTap: onExportData,
                    ),
                    if (isAnonymous)
                      ListTile(
                        key: AppKeys.eraseData,
                        leading: Icon(Icons.delete_forever_rounded, color: error),
                        title: Text(eraseData, style: textTheme.bodyLarge?.copyWith(color: error)),
                        onTap: () => _onEraseData(context),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isAnonymous) ...[
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
                ],
                _Section(
                  title: app,
                  children: [
                    const _NotificationsRow(),
                    // absent until there is a timer to list: an entry that can
                    // only open onto an empty page is a dead end
                    Selector<Timers, bool>(
                      selector: (_, timers) => timers.isNotEmpty,
                      builder: (_, any, _) {
                        return switch (any) {
                          true => ListTile(
                            key: AppKeys.restTimers,
                            leading: const Icon(Icons.timer_outlined),
                            title: Text(restTimers),
                            onTap: onRestTimers,
                          ),
                          false => const SizedBox.shrink(),
                        };
                      },
                    ),
                    const _LockScreenWorkoutSwitch(),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: Text(aboutApp),
                      onTap: () {
                        final info = AppInfo.of(context);

                        showAboutDialog(
                          context: context,
                          applicationVersion: info.fullVersion,
                          applicationName: AppConfig.of(context).appName,
                          // without one the dialog keeps the icon's slot anyway,
                          // and the name sat indented over an empty gap
                          applicationIcon: const _AppMark(),
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        // the dot (#216) while What's new holds unread notes; it
                        // goes when the page opens
                        final unread = WhatsNewBadge.watch(context).unread;
                        return ListTile(
                          key: AppKeys.whatsNew,
                          leading: const Icon(Icons.update_rounded),
                          title: Text(
                            whatsNew,
                            semanticsLabel: switch (unread) {
                              true => L.of(context).whatsNewUnread,
                              false => null,
                            },
                          ),
                          trailing: switch (unread) {
                            true => Badge(smallSize: 8, backgroundColor: Theme.of(context).colorScheme.tertiary),
                            false => null,
                          },
                          onTap: onWhatsNew,
                        );
                      },
                    ),
                    if (!isAnonymous)
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
      ),
    );
  }

  /// The same shape as account deletion's first dialog (account.dart): one
  /// confirmation, explicit about what goes, the destructive action in the
  /// error container. No password step — there is no credential to check an
  /// anonymous session against, and nothing on a server to protect.
  Future<void> _onEraseData(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final L(
      :eraseDataTitle,
      :eraseDataBody,
      :eraseDataCancelMessage,
      :eraseDataConfirmMessage,
    ) = L.of(
      context,
    );

    return showBrandedDialog(
      context,
      title: Text(
        eraseDataTitle,
        textAlign: TextAlign.center,
      ),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          eraseDataBody,
          textAlign: TextAlign.center,
        ),
      ),
      icon: Icon(
        Icons.delete_forever_rounded,
        color: colorScheme.error,
      ),
      actions: [
        _EraseDataActions(
          keepCopy: eraseDataCancelMessage,
          eraseCopy: eraseDataConfirmMessage,
          onErase: () {
            Navigator.of(context, rootNavigator: true).pop();
            _erase(context);
          },
        ),
      ],
    );
  }

  /// The same pair as the profile's log-out — theme is provided above
  /// heart_state's fan-out — with the wipe in between; then back to the
  /// profile, which is where a fresh session lands.
  Future<void> _erase(BuildContext context) async {
    buzz();
    AppTheme.of(context).onSignOut();
    await eraseState(context);
    if (!context.mounted) return;
    onErased();
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

/// The erase-my-data dialog's two actions: a neutral fill for keeping the
/// data, the error container for the wipe.
///
/// A widget rather than two buttons built where the dialog is opened, for the
/// reason the profile's no-account actions are: the fills come from the theme
/// the dialog is *showing* under, so a dark-mode flip while it is open
/// repaints them instead of leaving a light fill under dark-mode ink.
class _EraseDataActions extends StatelessWidget {
  final String keepCopy;
  final String eraseCopy;
  final VoidCallback onErase;

  const new({required this.keepCopy, required this.eraseCopy, required this.onErase});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Column(
      spacing: 8,
      children: [
        PrimaryButton.wide(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Center(
            child: Text(keepCopy),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        PrimaryButton.wide(
          key: AppKeys.eraseDataConfirm,
          backgroundColor: colorScheme.errorContainer,
          onPressed: onErase,
          child: Center(
            child: Text(
              eraseCopy,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled group of settings rows.
///
/// The title is a real header to assistive tech, so a screen reader can jump
/// section to section instead of row by row.
/// The opt-in for the workout on the lock screen (#133): the Live Activity
/// on iOS, the workout notification on Android. Off until turned on.
///
/// Absent rather than dead where there is nothing to show it on — the web,
/// the desktop, an iPad, iOS below 16.2. Turning it on for Android asks for
/// the notification permission it needs, if it was never granted; iOS asks
/// its own question the first time the activity reaches the lock screen.
class _LockScreenWorkoutSwitch extends StatefulWidget {
  const new();

  @override
  State<_LockScreenWorkoutSwitch> createState() => _LockScreenWorkoutSwitchState();
}

class _LockScreenWorkoutSwitchState extends State<_LockScreenWorkoutSwitch> {
  /// Asked once: the answer is a fact about the device, and a new future on
  /// every rebuild would blank the row each time the switch is flipped.
  late final Future<bool> _supported = switch ((kIsWeb, ongoingWorkoutSurface(Theme.of(context).platform))) {
    (false, OngoingWorkoutSurface surface) => surface.isSupported(),
    _ => Future.value(false),
  };

  @override
  Widget build(BuildContext context) {
    final L(:lockScreenWorkout, :lockScreenWorkoutSubtitle) = L.of(context);
    final preferences = Preferences.watch(context);
    final ThemeData(
      :platform,
      colorScheme: ColorScheme(:tertiaryContainer, :onTertiaryContainer, :outlineVariant),
    ) = Theme.of(
      context,
    );

    return FutureBuilder<bool>(
      future: _supported,
      builder: (context, snapshot) {
        return switch (snapshot.data) {
          true => SwitchListTile.adaptive(
            secondary: const Icon(Icons.screen_lock_portrait_rounded),
            title: Text(lockScreenWorkout),
            subtitle: Text(lockScreenWorkoutSubtitle),
            value: preferences.lockScreenWorkout,
            // the accent as a fill, like PrimaryButton — not the platform's
            // green; and a hairline track, so "off" is still a visible control
            activeTrackColor: tertiaryContainer,
            activeThumbColor: onTertiaryContainer,
            inactiveTrackColor: outlineVariant,
            onChanged: (on) {
              preferences.lockScreenWorkout = on;
              if (on && platform == .android) ensureNotificationPermission(platform);
            },
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

/// The way to the system's notification settings, its icon saying whether
/// they are on.
///
/// Its own widget so the permission is asked when the row is built, not when
/// the page is. The page is a lazy list: built by the page, the check ran for
/// a row that might never appear, and where the plugin is absent (a widget
/// test) its failure had nobody listening — a crash of the test, surfaced the
/// moment the Features section pushed this row below the first screen.
class const _NotificationsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final L(:notificationSettings) = L.of(context);
    return FutureBuilder<bool>(
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
    );
  }
}

/// The app's mark as the home screen shows it — a white heart on the accent
/// disc — drawn from the brand heart rather than a launcher bitmap, so it
/// follows the preset and both brightnesses.
class const _AppMark() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme(:primary, :onPrimary) = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        padding: const .all(12),
        decoration: BoxDecoration(color: primary, shape: .circle),
        child: Image.asset('assets/icons/heart.png', color: onPrimary),
      ),
    );
  }
}

/// The opt-in features (#138, `docs/opt-in.md`): one switch each, always
/// live, both ways. The switch is the answer — turning a feature on here does
/// not ask again, and turning it off takes it out of the app on the spot.
class const _FeaturesSection() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);

    return _Section(
      title: l.features,
      children: [
        for (final feature in Feature.values)
          switch (feature) {
            // only where there is a watch with Heart on it
            .watchApp => const _WatchAppSwitch(),
            _ => _FeatureSwitch(feature),
          },
        Padding(
          padding: const .symmetric(horizontal: 16),
          child: Text(l.featuresFooter, style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// One feature's switch: the answer, always live, both ways — and, while it
/// is on, what unfolds under it (#213): the parts of the feature the user can
/// leave out, and the notes worth knowing about it. Off, they fold away with
/// the feature.
class const _FeatureSwitch(final Feature feature, {final VoidCallback? onSwitched}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final preferences = Preferences.watch(context);
    final ThemeData(
      :textTheme,
      colorScheme: ColorScheme(:tertiaryContainer, :onTertiaryContainer, :outlineVariant, :onSurfaceVariant),
    ) = Theme.of(
      context,
    );
    final on = preferences.isOn(feature);
    final options = feature.options.toList();
    final notes = feature.notes(l);
    final unfolds = options.isNotEmpty || notes.isNotEmpty;

    final toggle = SwitchListTile.adaptive(
      key: ValueKey('feature-${feature.value}'),
      secondary: Icon(feature.icon),
      title: Text(feature.title(l)),
      subtitle: Text(feature.subtitle(l)),
      value: on,
      // the lock-screen switch's colors: the accent as a fill, and a
      // hairline track so "off" is still a visible control
      activeTrackColor: tertiaryContainer,
      activeThumbColor: onTertiaryContainer,
      inactiveTrackColor: outlineVariant,
      onChanged: (on) {
        preferences.setFeature(feature, on: on);
        onSwitched?.call();
      },
    );

    if (!unfolds) return toggle;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        // a switch that unfolds says so: expanded while on
        Semantics(expanded: on, child: toggle),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: .topCenter,
          child: switch (on) {
            false => const SizedBox(width: double.infinity),
            true => Padding(
              // under the title, past the switch's icon
              padding: const .fromLTRB(48, 0, 8, 8),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  for (final option in options)
                    CheckboxListTile.adaptive(
                      key: ValueKey('feature-${feature.value}-${option.value}'),
                      value: preferences.isOptionOn(option),
                      // leaving out the last one turns the feature off
                      onChanged: (checked) => preferences.setOption(option, on: checked ?? false),
                      title: Text(option.title(l)),
                      controlAffinity: ListTileControlAffinity.trailing,
                      dense: true,
                      visualDensity: .compact,
                      contentPadding: const .symmetric(horizontal: 8),
                      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
                    ),
                  for (final note in notes)
                    Padding(
                      padding: const .fromLTRB(8, 4, 8, 4),
                      child: Text(note, style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          },
        ),
      ],
    );
  }
}

/// The watch app's switch (#182) in Settings › Features.
///
/// Absent unless a paired watch has Heart installed — and it appears or goes
/// while the page is open, as the watch is paired or the app added to it. Its
/// value before the user has answered reads as off: the answer is opening
/// Heart on the watch, which turns it on without passing through here.
class _WatchAppSwitch extends StatefulWidget {
  const new();

  @override
  State<_WatchAppSwitch> createState() => _WatchAppSwitchState();
}

class _WatchAppSwitchState extends State<_WatchAppSwitch> {
  final _installed = ValueNotifier(false);
  late final WatchLink? _link = switch (kIsWeb) {
    false => watchLink(Theme.of(context).platform),
    true => null,
  };
  StreamSubscription<WatchEvent>? _events;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_events != null) return;
    if (_link case WatchLink link) {
      _check(link);
      _events = link.events.where((event) => event == .changed).listen((_) => _check(link));
    }
  }

  Future<void> _check(WatchLink link) async {
    final installed = await link.isInstalled();
    if (mounted) _installed.value = installed;
  }

  @override
  void dispose() {
    _events?.cancel();
    _installed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _installed,
      builder: (context, installed, _) {
        return switch (installed) {
          // its notes — the phone catching up (#206), Apple's Always On
          // switch (#213) — unfold under it with the rest of the feature
          true => _FeatureSwitch(
            .watchApp,
            onSwitched: () {
              final on = Preferences.of(context).isOn(.watchApp);
              Analytics.of(context).watchAppSwitched(on: on, fromWatch: false);
            },
          ),
          false => const SizedBox.shrink(),
        };
      },
    );
  }
}

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
