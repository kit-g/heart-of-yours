part of 'settings.dart';

/// What each version that shipped something new brought, newest first.
///
/// A list the user opens and nothing more — no badge, no sheet after an
/// update. The notes are bundled with the build (see [loadReleases]), so it
/// never waits on a network and has no loading or error state worth
/// drawing: the empty state is what a broken asset looks like, and the
/// content test is what keeps one from shipping.
class WhatsNewPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// Opens the Features page at a note's feature (#239). Without it, notes
  /// carry no button.
  final void Function(Feature)? onFeature;

  const new({super.key, this.onError, this.onFeature});

  @override
  State<WhatsNewPage> createState() => _WhatsNewPageState();
}

class _WhatsNewPageState extends State<WhatsNewPage> {
  Locale? _locale;
  late Future<List<Release>> _releases;

  @override
  void initState() {
    super.initState();
    // opened is read (#216): the dots on Settings go. After the frame — it
    // notifies, and this page is still being built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WhatsNewBadge.of(context).markRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // re-read on a language change, and only then — the future outlives
    // rebuilds, so the list does not blink back to nothing on each one
    final locale = Localizations.localeOf(context);
    if (locale != _locale) {
      _locale = locale;
      _releases = loadReleases(
        DefaultAssetBundle.of(context),
        locale,
        platform: defaultTargetPlatform,
        onError: widget.onError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final L(:whatsNew, :whatsNewEmpty) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(whatsNew),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: FutureBuilder<List<Release>>(
        future: _releases,
        builder: (context, snapshot) {
          return switch (snapshot) {
            AsyncSnapshot(connectionState: .done, data: List<Release> releases) when releases.isNotEmpty => _Releases(
              releases: releases,
              current: currentRelease(releases, AppInfo.of(context).version),
              onFeature: widget.onFeature,
            ),
            AsyncSnapshot(connectionState: .done) => Center(
              child: Padding(
                padding: const .all(24),
                child: Text(
                  whatsNewEmpty,
                  textAlign: .center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _Releases extends StatelessWidget {
  final List<Release> releases;
  final Release? current;
  final void Function(Feature)? onFeature;

  const new({required this.releases, this.current, this.onFeature});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // cards of prose — a readable column, not the pane's width
        final width = math.min(constraints.maxWidth, readableWidth);
        return Align(
          alignment: .topCenter,
          child: SizedBox(
            width: width,
            child: ListView.separated(
              padding: const .all(16),
              itemCount: releases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final release = releases[index];
                return _ReleaseCard(release: release, isCurrent: identical(release, current), onFeature: onFeature);
              },
            ),
          ),
        );
      },
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final Release release;
  final bool isCurrent;
  final void Function(Feature)? onFeature;

  const new({required this.release, required this.isCurrent, this.onFeature});

  @override
  Widget build(BuildContext context) {
    final L(:whatsNewThisVersion, :localeName) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final Release(:version, :date, :notes) = release;

    return Card(
      margin: .zero,
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // version, date and the marker announce as one heading
            MergeSemantics(
              child: Semantics(
                header: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: .center,
                  children: [
                    Text(version, style: textTheme.titleMedium),
                    if (date != null)
                      Text(
                        DateFormat.yMMMd(localeName).format(date),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    if (isCurrent)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: .all(color: colorScheme.primary),
                          borderRadius: const .all(.circular(8)),
                        ),
                        child: Padding(
                          padding: const .symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            whatsNewThisVersion,
                            style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ...notes.map(
              (note) => Padding(
                padding: const .only(top: 12),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    // the title and every run of the markdown body, as one node
                    MergeSemantics(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(note.title, style: textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Prose(note.body),
                        ],
                      ),
                    ),
                    // a tap target of its own, outside the merged node
                    if ((note.feature, onFeature) case (Feature feature, final onFeature?))
                      _FeatureButton(feature, onPressed: () => onFeature(feature)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Under a note about an opt-in feature (#239): the way to its switch, saying
/// where the user stands with it — an invitation while it is off, the fact
/// while it is on. Either way it only takes them there; the switch is the
/// answer.
class const _FeatureButton(final Feature feature, {required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final L(:whatsNewFeatureOff, :whatsNewFeatureOn) = L.of(context);
    final on = Preferences.watch(context).isOn(feature);
    return Padding(
      padding: const .only(top: 4),
      child: TextButton.icon(
        key: ValueKey('whats-new-feature-${feature.value}'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onPressed,
        icon: Icon(switch (on) {
          true => Icons.check_rounded,
          false => feature.icon,
        }),
        label: Text(switch (on) {
          true => whatsNewFeatureOn,
          false => whatsNewFeatureOff,
        }),
      ),
    );
  }
}
