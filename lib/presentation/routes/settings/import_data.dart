part of 'settings.dart';

/// Where a workout-history import ends up: the server's report on success, or
/// its refusal when the file was not a readable export.
sealed class _ImportOutcome {
  const new();
}

final class _Imported extends _ImportOutcome {
  final WorkoutImportReport report;

  const new(this.report);
}

final class _Rejected extends _ImportOutcome {
  final String? reason;

  const new(this.reason);
}

/// Uploads a Strong CSV export and shows the server's report.
///
/// The server does all parsing, matching and dedup — this page is transport
/// and UX. The import is idempotent, so there is no confirmation dialog and
/// no warning against re-picking the same file: choosing a file is safe by
/// construction.
class ImportDataPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, this.onError});

  @override
  State<ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends State<ImportDataPage> with LoadingState<ImportDataPage>, HasHaptic<ImportDataPage> {
  final _outcome = ValueNotifier<_ImportOutcome?>(null);

  @override
  void dispose() {
    _outcome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :importData,
      :importExplainerStrong,
      :importSafeToRetry,
      :chooseFile,
      :importInFlight,
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(importData),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // this page is prose and one button — cap it at a readable column
          // rather than letting an iPad stretch it to the pane edge
          final width = math.min(constraints.maxWidth, readableWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(importExplainerStrong),
                  const SizedBox(height: 12),
                  Text(
                    importSafeToRetry,
                    style: textTheme.bodySmall,
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
                              importInFlight,
                              style: textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        false => PrimaryButton.wide(
                          backgroundColor: colorScheme.primaryContainer,
                          // the default padding renders 32pt tall; the primary
                          // action on this page should make a 48pt tap target
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 14),
                          onPressed: () => _onChooseFile(context),
                          child: Center(
                            child: Text(chooseFile),
                          ),
                        ),
                      };
                    },
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<_ImportOutcome?>(
                    valueListenable: _outcome,
                    builder: (_, outcome, _) {
                      return switch (outcome) {
                        null => const SizedBox.shrink(),
                        _Imported(:final report) => _ImportReportView(report: report),
                        _Rejected(:final reason) => _ImportRejectionView(reason: reason),
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

  Future<void> _onChooseFile(BuildContext context) async {
    buzz();
    final workouts = Workouts.of(context);
    final exercises = Exercises.of(context);
    final preferences = Preferences.of(context);
    // the unit fields are `late` and this page can be reached before the
    // startup read lands — the parameter is an optional fallback anyway
    final unit = switch (preferences.isInitialized) {
      true => preferences.weightUnit,
      false => null,
    };
    final messenger = ScaffoldMessenger.of(context);

    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: L.of(context).csvFiles,
          extensions: const ['csv'],
          mimeTypes: const ['text/csv', 'text/comma-separated-values'],
          uniformTypeIdentifiers: const ['public.comma-separated-values-text', 'public.plain-text'],
        ),
      ],
    );
    if (file == null) return; // backed out of the picker

    startLoading();
    _outcome.value = null;
    try {
      final report = await Api.instance.importWorkouts(
        await file.readAsString(),
        // fallback for exports whose rows carry no unit columns; ignored when
        // the CSV declares its own
        unit: unit,
        // Strong timestamps are naive local time
        tzOffset: DateTime.now().timeZoneOffset,
      );
      _outcome.value = _Imported(report);
      // The imported workouts exist server-side only until the mirrors
      // refresh. Fire and forget: the report above is the confirmation, and
      // older pages fill in as the user pages back through history. The chain
      // is ordered like startup (see app.dart): history rows hold a foreign
      // key onto `exercises.name`, and an import that created custom
      // exercises must land them in the catalog before the mirror writes
      // workouts that reference them.
      unawaited(
        exercises
            .init()
            .then((_) => workouts.initHistory())
            .catchError((e, s) => widget.onError?.call(e, stacktrace: s)),
      );
    } on ImportRejected catch (e) {
      _outcome.value = _Rejected(e.reason);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }
}

class _ImportReportView extends StatelessWidget {
  final WorkoutImportReport report;

  const new({required this.report});

  @override
  Widget build(BuildContext context) {
    final L(
      :importReportTitle,
      :importedWorkouts,
      :importSkippedWorkouts,
      :importedSets,
      :importSkippedRows,
      :importNewExercisesHeader,
      :importNewExercisesBody,
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final WorkoutImportReport(
      :workoutsCreated,
      :workoutsSkipped,
      :setsCreated,
      :exercisesCreated,
      :rowsSkipped,
    ) = report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: colorScheme.primary,
            ),
            Text(
              importReportTitle,
              style: textTheme.titleMedium,
            ),
          ],
        ),
        Text(importedWorkouts(workoutsCreated)),
        if (setsCreated > 0) Text(importedSets(setsCreated)),
        if (workoutsSkipped > 0) Text(importSkippedWorkouts(workoutsSkipped)),
        if (rowsSkipped > 0)
          Text(
            importSkippedRows(rowsSkipped),
            style: textTheme.bodySmall,
          ),
        if (exercisesCreated.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            importNewExercisesHeader,
            style: textTheme.titleSmall,
          ),
          Text(
            importNewExercisesBody,
            style: textTheme.bodySmall,
          ),
          for (final name in exercisesCreated) Text('•  $name'),
        ],
      ],
    );
  }
}

class _ImportRejectionView extends StatelessWidget {
  final String? reason;

  const new({required this.reason});

  @override
  Widget build(BuildContext context) {
    final L(:importFailedHeadline, :importFailedBody) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
            ),
            Text(
              importFailedHeadline,
              style: textTheme.titleMedium,
            ),
          ],
        ),
        Text(importFailedBody),
        // the server's own words — developer-grade, so detail text, not the
        // headline
        if (reason case String detail)
          Text(
            detail,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
      ],
    );
  }
}
