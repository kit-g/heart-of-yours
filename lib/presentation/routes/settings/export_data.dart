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
/// Reads the local store, never the server — the point of the export is that
/// it costs nothing and works without a network or an account. The sheet is
/// the confirmation: once it opens the page has nothing left to say, and a
/// second export is as safe as the first.
///
/// It says nothing about how much of the account the file holds, because it no
/// longer has to: `Backfill` makes the mirror whole in the background (#113).
/// A page that asks the user to go and scroll History before exporting is the
/// app handing them its own bookkeeping.
class ExportDataPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, this.onError});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> with LoadingState<ExportDataPage>, HasHaptic<ExportDataPage> {
  @override
  Widget build(BuildContext context) {
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
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme) = Theme.of(context);
    final isAnonymous = Auth.watch(context).isAnonymous;

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
