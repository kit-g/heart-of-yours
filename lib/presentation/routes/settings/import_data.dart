part of 'settings.dart';

/// Where a workout-history import stands: awaiting the user's word on
/// unmatched exercises, the server's report on success, or its refusal when
/// the file was not a readable export.
sealed class _ImportOutcome {
  const new();
}

/// The preview found exercise names that would become the user's custom
/// exercises — customs can only ever be archived, not deleted, so each one
/// needs the user's yes before it exists. Holds the picked file's contents
/// for the commit that follows.
final class _AwaitingConsent extends _ImportOutcome {
  final WorkoutImportPreview preview;
  final String csv;

  const new(this.preview, {required this.csv});
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
                  ValueListenableBuilder<_ImportOutcome?>(
                    valueListenable: _outcome,
                    builder: (_, outcome, child) {
                      return switch (outcome) {
                        // the consent card below owns the actions — a second
                        // file is a decision for after this one
                        _AwaitingConsent() => const SizedBox.shrink(),
                        _ => child!,
                      };
                    },
                    child: ValueListenableBuilder<bool>(
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
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<_ImportOutcome?>(
                    valueListenable: _outcome,
                    builder: (_, outcome, _) {
                      return switch (outcome) {
                        null => const SizedBox.shrink(),
                        _AwaitingConsent(:final preview, :final csv) => _ImportConsentView(
                          preview: preview,
                          onImport: (approved) => _commit(csv, createCustom: approved),
                          onCancel: () => _outcome.value = null,
                        ),
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

  /// The unit fields are `late` and this page can be reached before the
  /// startup read lands — the parameter is an optional fallback anyway.
  MeasurementUnit? get _fallbackUnit {
    final preferences = Preferences.of(context);
    return switch (preferences.isInitialized) {
      true => preferences.weightUnit,
      false => null,
    };
  }

  /// The dry run: nothing is written until the user has said which unmatched
  /// exercises may become their customs — those can only be archived, never
  /// deleted, so consent comes first. A preview with nothing unmatched has
  /// nothing to ask and commits straight away.
  Future<void> _onChooseFile(BuildContext context) async {
    buzz();
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
      final csv = await file.readAsString();
      final preview = await Api.instance.previewImportedWorkouts(
        csv,
        // fallback for exports whose rows carry no unit columns; ignored when
        // the CSV declares its own
        unit: _fallbackUnit,
        // Strong timestamps are naive local time
        tzOffset: DateTime.now().timeZoneOffset,
      );
      switch (preview.exercisesUnmatched) {
        case []:
          await _commit(csv);
        case _:
          _outcome.value = _AwaitingConsent(preview, csv: csv);
      }
    } on ImportRejected catch (e) {
      _outcome.value = _Rejected(e.reason);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }

  /// The commit half. [createCustom] carries the user's decision (absent when
  /// the preview found nothing to decide); sets on a declined name are
  /// skipped server-side and come back counted in the report.
  Future<void> _commit(String csv, {List<String>? createCustom}) async {
    buzz();
    final workouts = Workouts.of(context);
    final exercises = Exercises.of(context);
    final messenger = ScaffoldMessenger.of(context);

    startLoading();
    // drops the consent card, so its button cannot double-submit while the
    // upload is in flight
    _outcome.value = null;
    try {
      final report = await Api.instance.importWorkouts(
        csv,
        unit: _fallbackUnit,
        tzOffset: DateTime.now().timeZoneOffset,
        createCustom: createCustom,
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

/// The preview: what the file holds, what already matches, and — the part
/// that needs the user's word — each unmatched exercise as its own decision.
///
/// Every name starts approved — the import's promise is "everything comes
/// over", and unchecking is the exception. Import commits whatever is checked
/// at that moment; nothing exists server-side until then, so Cancel simply
/// walks away.
class _ImportConsentView extends StatefulWidget {
  final WorkoutImportPreview preview;
  final void Function(List<String> approved) onImport;
  final VoidCallback onCancel;

  const new({required this.preview, required this.onImport, required this.onCancel});

  @override
  State<_ImportConsentView> createState() => _ImportConsentViewState();
}

class _ImportConsentViewState extends State<_ImportConsentView> {
  late final _approved = ValueNotifier<Set<String>>({
    for (final (:name, sets: _) in widget.preview.exercisesUnmatched) name,
  });

  @override
  void dispose() {
    _approved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :importPreviewTitle,
      :importPreviewSummary,
      :importPreviewSummaryPartial,
      :importPreviewNothingNew,
      :importPreviewMatched,
      :importPreviewAlreadyHere,
      :importConsentTitle,
      :importConsentBody,
      :importAction,
      :importSetsCount,
      :selectAll,
      :deselectAll,
      :cancel,
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final WorkoutImportPreview(
      :workoutsFound,
      :workoutsAlreadyImported,
      :setsFound,
      :exercisesMatched,
      :exercisesUnmatched,
    ) = widget.preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              color: colorScheme.primary,
            ),
            Text(
              importPreviewTitle,
              style: textTheme.titleMedium,
            ),
          ],
        ),
        // the stock half of the story: what would actually import — the
        // file's totals only speak for a file none of which is here yet
        switch (workoutsFound - workoutsAlreadyImported) {
          0 => Text(importPreviewNothingNew(workoutsFound)),
          final fresh when fresh == workoutsFound => Text(importPreviewSummary(workoutsFound, setsFound)),
          final fresh => Text(importPreviewSummaryPartial(fresh)),
        },
        if (exercisesMatched > 0) Text(importPreviewMatched(exercisesMatched)),
        // redundant when the nothing-new line above already said it all
        if (workoutsAlreadyImported > 0 && workoutsAlreadyImported < workoutsFound)
          Text(importPreviewAlreadyHere(workoutsAlreadyImported)),
        const SizedBox(height: 8),
        ValueListenableBuilder<Set<String>>(
          valueListenable: _approved,
          builder: (_, approved, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // the title yields to the toggle — on a narrow pane it
                    // wraps rather than pushing the button off the edge
                    Expanded(
                      child: Text(
                        importConsentTitle,
                        style: textTheme.titleSmall,
                      ),
                    ),
                    // one tap to clear the lot and cherry-pick, or to take
                    // everything back; "any selection" beats "all selected"
                    // as the flip point — from a mixed state the likely
                    // intent is a clean slate
                    TextButton(
                      onPressed: () {
                        _approved.value = switch (approved.isEmpty) {
                          true => {for (final (:name, sets: _) in exercisesUnmatched) name},
                          false => const {},
                        };
                      },
                      child: Text(
                        switch (approved.isEmpty) {
                          true => selectAll,
                          false => deselectAll,
                        },
                      ),
                    ),
                  ],
                ),
                Text(
                  importConsentBody,
                  style: textTheme.bodySmall,
                ),
                for (final (:name, :sets) in widget.preview.exercisesUnmatched)
                  // .adaptive: a Cupertino check on Apple platforms, Material
                  // elsewhere — the app's first checkbox, so this is the idiom
                  CheckboxListTile.adaptive(
                    value: approved.contains(name),
                    onChanged: (checked) {
                      _approved.value = switch (checked) {
                        true => {...approved, name},
                        _ => {...approved}..remove(name),
                      };
                    },
                    title: Text(name),
                    subtitle: Text(importSetsCount(sets)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    // a slim inset keeps the ink from running flush against
                    // the text column; the shape rounds it like the pickers
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
              ],
            );
          },
        ),
        // the dialogs' pair, laid flat: a muted way out and the one action —
        // both at the same 48pt target as the page's Choose-file button
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: PrimaryButton.wide(
                backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 14),
                onPressed: widget.onCancel,
                child: Center(
                  child: Text(cancel),
                ),
              ),
            ),
            Expanded(
              child: PrimaryButton.wide(
                backgroundColor: colorScheme.primaryContainer,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 14),
                onPressed: () {
                  // in export order, not tap order
                  widget.onImport([
                    for (final (:name, sets: _) in exercisesUnmatched)
                      if (_approved.value.contains(name)) name,
                  ]);
                },
                child: Center(
                  child: Text(importAction),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
      :importSkippedSets,
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
      :setsSkipped,
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
        if (setsSkipped > 0) Text(importSkippedSets(setsSkipped)),
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
