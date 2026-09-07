part of 'settings.dart';

/// The two files the page can write.
enum _ExportFormat {
  json,
  csv;

  String get mimeType => switch (this) {
    json => 'application/json',
    csv => 'text/csv',
  };
}

/// Hands the user everything the device holds, as a file through the system
/// share sheet.
///
/// The file is written from the local store, never the server — the point of
/// the export is that it costs nothing and works without a network or an
/// account. The sheet is the confirmation: once it opens the page has nothing
/// left to say, and a second export is as safe as the first.
///
/// The one server read is the completeness check, and it goes the other way:
/// it never adds a row to the file, it only says whether the store the file
/// comes from is the whole account (heart-api#75). Both buttons work without
/// it.
class ExportDataPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, this.onError});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> with LoadingState<ExportDataPage>, HasHaptic<ExportDataPage> {
  /// What the account holds that this device does not, or `null` while the
  /// question is still open — unasked, unanswerable, or refused.
  ///
  /// `null` is not "complete": an export off a partial mirror looks exactly
  /// like a whole one, so the page falls back to what it can see for itself
  /// rather than promise a file it has not measured.
  final _gaps = ValueNotifier<List<MirrorGap>?>(null);

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _gaps.dispose();
    super.dispose();
  }

  /// One read, when the page opens. An anonymous session skips it: its mirror
  /// *is* the account, so there is nothing to measure it against.
  Future<void> _check() async {
    final Auth(:isAnonymous, :user) = Auth.of(context);
    if (isAnonymous) return;

    if (user?.id case String id) {
      final gaps = await DataExport.of(context).completeness(id);
      if (mounted) _gaps.value = gaps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final L(
      :exportData,
      :exportExplainer,
      :exportNoHealthData,
      :noAccountBodyLose,
      :exportAsJson,
      :exportJsonHint,
      :exportAsCsv,
      :exportCsvHint,
      :exportInFlight,
    ) = l;
    final ThemeData(:textTheme) = Theme.of(context);
    final isAnonymous = Auth.watch(context).isAnonymous;
    // The fallback, for when the account's own totals could not be read: the
    // history list knows whether it has paged everything down, which covers
    // workouts and nothing else. Nothing to say before the first page has
    // landed, or once the server has no more.
    final Workouts(:hasMoreHistory, :historyInitialized, :history) = Workouts.watch(context);
    final partial = !isAnonymous && historyInitialized && hasMoreHistory;

    return Scaffold(
      appBar: AppBar(
        title: Text(exportData),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // prose and two buttons — a readable column, not the pane's width
          final width = math.min(constraints.maxWidth, readableWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(exportExplainer),
                  const SizedBox(height: 12),
                  Text(
                    exportNoHealthData,
                    style: textTheme.bodySmall,
                  ),
                  // the no-account dialog's last line, once — this is the one
                  // place an anonymous session can act on it
                  if (isAnonymous) ...[
                    const SizedBox(height: 12),
                    Text(
                      noAccountBodyLose,
                      style: textTheme.bodySmall,
                    ),
                  ],
                  ValueListenableBuilder<List<MirrorGap>?>(
                    valueListenable: _gaps,
                    builder: (_, gaps, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final line in _shortfall(l, gaps: gaps, partial: partial, held: history.length)) ...[
                            const SizedBox(height: 12),
                            Text(line, style: textTheme.bodySmall),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<bool>(
                    valueListenable: loader,
                    builder: (_, loading, _) {
                      return switch (loading) {
                        true => Column(
                          children: [
                            const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              exportInFlight,
                              style: textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        false => Column(
                          crossAxisAlignment: .start,
                          children: [
                            _FormatAction(
                              key: AppKeys.exportJson,
                              label: exportAsJson,
                              hint: exportJsonHint,
                              onPressed: () => _export(context, .json),
                            ),
                            const SizedBox(height: 16),
                            _FormatAction(
                              key: AppKeys.exportCsv,
                              label: exportAsCsv,
                              hint: exportCsvHint,
                              onPressed: () => _export(context, .csv),
                            ),
                          ],
                        ),
                      };
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// What the file will be missing, as lines of copy — none when it will be
  /// whole.
  ///
  /// Three states, and the middle one is why [gaps] is not a boolean: an empty
  /// list means the mirror was measured against the account and is whole, so
  /// the page says nothing; `null` means it could not be measured, and the
  /// page falls back to the one thing it can see without the server — whether
  /// the history list has paged everything down; a non-empty list is the
  /// measured shortfall.
  ///
  /// Only the workouts count is spelled out. It is the collection that is
  /// routinely a prefix, the only one with somewhere for the user to go, and
  /// the only shortfall a number makes concrete; the rest are one line,
  /// because "3 of your 5 folders" is noise, not an action. A collection
  /// holding as many rows as the account under a different newest row joins
  /// them: the file would be complete by count and still not be the account.
  static Iterable<String> _shortfall(L l, {required List<MirrorGap>? gaps, required bool partial, required int held}) {
    return switch (gaps) {
      null => [if (partial) l.exportPartialHistory(held)],
      [] => const <String>[],
      final found => [
        for (final gap in found)
          if (gap case (collection: .workouts, :final local, :final remote, diverged: false))
            l.exportPartialHistoryOf(local, remote),
        if (found.any((gap) => gap.collection != ExportableCollection.workouts || gap.diverged)) l.exportPartialAccount,
      ],
    };
  }

  /// Reads the store, writes the file, opens the sheet. The share result is
  /// not read: the sheet is the user's, and nothing here depends on what they
  /// did with it.
  Future<void> _export(BuildContext context, _ExportFormat format) async {
    buzz();
    final messenger = ScaffoldMessenger.of(context);
    final userId = Auth.of(context).user?.id;
    if (userId == null) return;
    final preferences = Preferences.of(context);
    // where the iPad's popover points; ignored everywhere else
    final origin = switch (context.findRenderObject()) {
      RenderBox box => box.localToGlobal(Offset.zero) & box.size,
      _ => null,
    };

    startLoading();
    try {
      final snapshot = await DataExport.of(context).read(
        userId,
        // `late` until the startup read lands, and this page can be reached
        // before it does — the same guard the unit pickers apply
        weightUnit: switch (preferences.isInitialized) {
          true => preferences.weightUnit,
          false => .metric,
        },
        distanceUnit: switch (preferences.isInitialized) {
          true => preferences.distanceUnit,
          false => .metric,
        },
      );
      final now = DateTime.now();
      final content = switch (format) {
        .json => snapshot.toJson(exportedAt: now),
        .csv => snapshot.toCsv(),
      };
      final name = 'heart-export-${_date(now)}.${format.name}';
      // the file is ready: the sheet that follows is the user's to take their
      // time over, and a progress bar under it would claim otherwise
      stopLoading();
      await SharePlus.instance.share(
        ShareParams(
          // in memory, no temp file of our own: the plugin writes one where
          // the OS may reclaim it, which is exactly the lifetime it should have
          files: [XFile.fromData(utf8.encode(content), mimeType: format.mimeType, name: name)],
          // `XFile.fromData` keeps its name on the web only
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }

  static String _date(DateTime at) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${pad(at.month)}-${pad(at.day)}';
  }
}

/// One format: the action, and the one line that says what it writes.
///
/// The button carries the same 48pt target the import page's does; the hint
/// is under it rather than inside so the label stays the one thing the button
/// announces.
class _FormatAction extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onPressed;

  const new({super.key, required this.label, required this.hint, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        PrimaryButton.wide(
          margin: const .symmetric(horizontal: 8.0, vertical: 14),
          onPressed: onPressed,
          child: Center(
            child: Text(label),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const .symmetric(horizontal: 8.0),
          child: Text(
            hint,
            style: textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
