part of 'settings.dart';

/// The opt-in features (#138, `docs/opt-in.md`), on a page of their own
/// (#226): every feature after 1.9.0 lands here, each with its parts and
/// notes, which a section of Settings would soon not hold. One switch each,
/// always live, both ways. The switch is the answer — turning a feature on
/// here does not ask again, and turning it off takes it out of the app on the
/// spot.
class FeaturesPage extends StatefulWidget {
  /// The feature to open at (#239), from a What's new note or a link from
  /// outside the app: its row is scrolled to and lit up for a moment. Opening
  /// here changes nothing — the switch is still the answer.
  final Feature? focus;

  /// What sent the user to [focus]; meaningless without one.
  final FeatureLinkSource source;

  const new({super.key, this.focus, this.source = .link});

  @override
  State<FeaturesPage> createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage> {
  final _focused = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focus case Feature feature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Analytics.of(context).featureLinked(feature: feature, source: widget.source);
        if (_focused.currentContext case BuildContext row) {
          Scrollable.ensureVisible(row, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, colorScheme: ColorScheme(:onSurfaceVariant)) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.features),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // a title and its switch per row: across a tablet pane they end up
          // too far apart to read as one line
          return Align(
            alignment: .topCenter,
            child: SizedBox(
              width: math.min(constraints.maxWidth, readableWidth),
              child: ListView(
                padding: const .symmetric(vertical: 8),
                children: [
                  for (final feature in Feature.values)
                    switch (feature == widget.focus) {
                      true => _Spotlight(key: _focused, child: _row(feature)),
                      false => _row(feature),
                    },
                  Padding(
                    padding: const .fromLTRB(16, 8, 16, 16),
                    child: Text(l.featuresFooter, style: textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(Feature feature) {
    return switch (feature) {
      // only where there is a watch with Heart on it
      .watchApp => const _WatchAppSwitch(),
      .rpe => _FeatureSwitch(
        .rpe,
        onSwitched: () => Analytics.of(context).rpeSwitched(on: Preferences.of(context).isOn(.rpe)),
      ),
      _ => _FeatureSwitch(feature),
    };
  }
}

/// The row a link opened Features at (#239), lit for a moment so the eye
/// finds it among the others, then fading back to the page's surface. With
/// animations off it is simply lit, then not.
class _Spotlight extends StatefulWidget {
  final Widget child;

  const new({super.key, required this.child});

  @override
  State<_Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<_Spotlight> {
  final _lit = ValueNotifier(true);
  late final Timer _dim;

  @override
  void initState() {
    super.initState();
    _dim = Timer(const Duration(seconds: 2), () => _lit.value = false);
  }

  @override
  void dispose() {
    _dim.cancel();
    _lit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme(:tertiaryContainer) = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _lit,
      builder: (context, lit, child) {
        return AnimatedContainer(
          duration: switch (still) {
            true => Duration.zero,
            false => const Duration(milliseconds: 600),
          },
          curve: Curves.easeOut,
          // edge to edge, like a selected row: an inset would pull this one
          // row's content out of line with the rest
          color: switch (lit) {
            true => tertiaryContainer.withValues(alpha: .35),
            false => tertiaryContainer.withValues(alpha: 0),
          },
          child: child,
        );
      },
      // the row's ink lands on the nearest Material, which would otherwise be
      // under the light rather than over it
      child: Material(type: .transparency, child: widget.child),
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

/// The watch app's switch (#182) on the Features page.
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
