part of 'settings.dart';

/// Where a workout-history import stands: awaiting the user's word on
/// unmatched exercises, the server's report on success, its refusal when the
/// file was not a readable export, or a file it kept to import by hand.
sealed class _ImportOutcome {
  const new();
}

/// Who reads the picked file. Every CSV goes to the server; Heart's own JSON
/// export is read by the app into its store (#329, heart-api#175), which is
/// why it is the one import that works without an account.
enum _Format { csv, json }

/// The preview found exercise names that would become the user's custom
/// exercises — customs can only ever be archived, not deleted, so each one
/// needs the user's yes before it exists. Holds the picked file's contents
/// for the commit that follows.
final class _AwaitingConsent extends _ImportOutcome {
  final WorkoutImportPreview preview;
  final String file;

  /// The source the preview ran as — the commit goes up as the same, whatever
  /// the switch says by then.
  final ImportSource source;

  final _Format format;

  const new(this.preview, {required this.file, required this.source, required this.format});
}

final class _Imported extends _ImportOutcome {
  final WorkoutImportReport report;

  /// What a Heart JSON export brings beside workouts; null for a CSV, which
  /// carries none of it.
  final ({int templates, int folders, int goals})? alongside;

  const new(this.report, {this.alongside});
}

final class _Rejected extends _ImportOutcome {
  final String? reason;
  final ImportSource source;

  /// A Heart export from a newer build, in a layout this one cannot read.
  final bool newer;

  const new(this.reason, {required this.source, this.newer = false});
}

/// The server's 202 (#324): a file in a known layout that nothing could read
/// automatically — today a hevy.com export in a language other than English.
/// It was kept, a person imports it, and the user hears back; nothing was
/// imported, and sending it again changes nothing.
final class _Parked extends _ImportOutcome {
  final String? reason;

  const new(this.reason);
}

/// Uploads a Strong, Hevy or Heart CSV export and shows the server's report,
/// or reads Heart's own JSON export into the store ([DataImport], #329).
///
/// For a CSV the server does all parsing, matching and dedup — this page is
/// transport and UX. Either import is idempotent, so there is no confirmation
/// dialog and no warning against re-picking the same file: choosing a file is
/// safe by construction.
///
/// Without an account only the JSON can be read, so the page offers only that
/// and asks nothing about where the file came from.
class ImportDataPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, this.onError});

  @override
  State<ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends State<ImportDataPage> with LoadingState<ImportDataPage>, HasHaptic<ImportDataPage> {
  final _outcome = ValueNotifier<_ImportOutcome?>(null);

  /// Which app the export came from (#324), Heart's own CSV included (#357).
  /// The server reads each in its own layout, so the user says which rather
  /// than the page guessing.
  final _source = ValueNotifier<ImportSource>(.strong);

  /// The unit the export was made in (#307), as the user says — null until
  /// they do, which reads as the account's own. Strong's CSV carries no unit,
  /// and only the person who exported knows which Strong was set to: a
  /// pounds export read as kilograms is stored 2.2 times too heavy, silently.
  final _unit = ValueNotifier<MeasurementUnit?>(null);

  /// Whether the import on screen brought ratings with it (#244): the store
  /// holds more rated sets after it than before. Only ever opens the RPE
  /// offer's slot under the report; whether anything shows there is the RPE
  /// answer's business.
  final _ratingsArrived = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _outcome.dispose();
    _source.dispose();
    _unit.dispose();
    _ratingsArrived.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :importData,
      :importSourceTitle,
      :importExplainerStrong,
      :importExplainerHevy,
      :importExplainerHeart,
      :importExplainerHeartJson,
      :importSafeToRetry,
      :importUnitTitle,
      :importUnitBody,
      :kg,
      :lbs,
      :chooseFile,
      :importInFlight,
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final anonymous = Auth.of(context).isAnonymous;

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
                  // no account, no server: Heart's own JSON is the one file
                  // there is, so there is nothing to choose between
                  if (anonymous) ...[
                    Text(importExplainerHeartJson),
                    const SizedBox(height: 12),
                    Text(
                      importSafeToRetry,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Text(importSourceTitle, style: textTheme.titleSmall),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<ImportSource>(
                      valueListenable: _source,
                      builder: (context, source, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SettingSwitcher<ImportSource>(
                              value: source,
                              onValueChanged: (value) => _source.value = value ?? source,
                              // the apps' own names, never translated
                              children: const {
                                .strong: Text('Strong'),
                                .hevy: Text('Hevy'),
                                .heart: Text('Heart'),
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              switch (source) {
                                .strong => importExplainerStrong,
                                .hevy => importExplainerHevy,
                                .heart => importExplainerHeart,
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              importSafeToRetry,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 24),
                            // which unit the export is in (#307): asked before the
                            // file, preset to the account's, read by both halves of
                            // the import. Hevy and Heart files name their units in
                            // their own rows, so the question has no form for them.
                            if (source == .strong) ...[
                              Text(importUnitTitle, style: textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(importUnitBody, style: textTheme.bodySmall),
                              const SizedBox(height: 12),
                              ValueListenableBuilder<MeasurementUnit?>(
                                valueListenable: _unit,
                                builder: (context, chosen, _) {
                                  return SettingSwitcher<MeasurementUnit>(
                                    value: chosen ?? _fallbackUnit ?? .metric,
                                    onValueChanged: (value) => _unit.value = value,
                                    children: {
                                      .metric: Text(kg),
                                      .imperial: Text(lbs),
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
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
                        _AwaitingConsent(:final preview, :final file, :final source, :final format) =>
                          _ImportConsentView(
                            preview: preview,
                            onImport: (approved) => _commit(
                              file,
                              source: source,
                              format: format,
                              createCustom: approved,
                            ),
                            onCancel: () => _outcome.value = null,
                          ),
                        _Imported(:final report, :final alongside) => Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            _ImportReportView(
                              report: report,
                              alongside: alongside,
                            ),
                            _ImportRpeOffer(ratingsArrived: _ratingsArrived),
                          ],
                        ),
                        _Rejected(:final reason, :final source, :final newer) => _ImportRejectionView(
                          reason: reason,
                          source: source,
                          newer: newer,
                        ),
                        _Parked(:final reason) => _ImportParkedView(reason: reason),
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

  /// The account's unit, which is what the question above starts on. The
  /// unit fields are `late` and this page can be reached before the startup
  /// read lands — the parameter is an optional fallback anyway.
  MeasurementUnit? get _fallbackUnit {
    final preferences = Preferences.of(context);
    return switch (preferences.isInitialized) {
      true => preferences.weightUnit,
      false => null,
    };
  }

  /// What the import sends: the export's unit as the user said, else the
  /// account's. The server reads it only for rows that carry no unit of
  /// their own, and applies it to weights and distances alike — which a
  /// Hevy or Heart row never is, so those imports send none.
  MeasurementUnit? _exportUnit(ImportSource source) {
    return switch (source) {
      .strong => _unit.value ?? _fallbackUnit,
      .hevy || .heart => null,
    };
  }

  /// What anchors the export's timestamps. Strong and Hevy write naive local
  /// time, read as this device's offset; Heart writes instants with their own
  /// offset, so a Heart import sends none.
  Duration? _exportOffset(ImportSource source) {
    return switch (source) {
      .strong || .hevy => DateTime.now().timeZoneOffset,
      .heart => null,
    };
  }

  /// The dry run: nothing is written until the user has said which unmatched
  /// exercises may become their customs — those can only be archived, never
  /// deleted, so consent comes first. A preview with nothing unmatched has
  /// nothing to ask and commits straight away.
  Future<void> _onChooseFile(BuildContext context) async {
    buzz();
    final messenger = ScaffoldMessenger.of(context);
    final dataImport = DataImport.of(context);
    final userId = Auth.of(context).user?.id;
    final L(:csvFiles, :jsonFiles) = L.of(context);
    final anonymous = Auth.of(context).isAnonymous;
    final source = switch (anonymous) {
      true => ImportSource.heart,
      false => _source.value,
    };

    final file = await openFile(
      acceptedTypeGroups: [
        if (!anonymous)
          XTypeGroup(
            label: csvFiles,
            extensions: const ['csv'],
            mimeTypes: const ['text/csv', 'text/comma-separated-values'],
            uniformTypeIdentifiers: const ['public.comma-separated-values-text', 'public.plain-text'],
          ),
        if (source == .heart)
          XTypeGroup(
            label: jsonFiles,
            extensions: const ['json'],
            mimeTypes: const ['application/json'],
            uniformTypeIdentifiers: const ['public.json'],
          ),
      ],
    );
    if (file == null) return; // backed out of the picker

    startLoading();
    _outcome.value = null;
    _ratingsArrived.value = false;
    try {
      final text = await file.readAsString();
      final format = _formatOf(source, text);
      final preview = switch ((format, userId)) {
        (.json, String uid) => _asPreview(await dataImport.preview(text, uid)),
        (.json, null) => throw StateError('an import with no session to import into'),
        (.csv, _) => await Api.instance.previewImportedWorkouts(
          text,
          source: source,
          // for exports whose rows carry no unit columns (#307); ignored when
          // the CSV declares its own
          unit: _exportUnit(source),
          tzOffset: _exportOffset(source),
        ),
      };
      // Held for the commit, which happens either immediately or a consent
      // step later and cannot see the preview by then.
      _unmatchedInPreview = preview.exercisesUnmatched.length;
      switch (preview.exercisesUnmatched) {
        case []:
          await _commit(text, source: source, format: format);
        case _:
          _outcome.value = _AwaitingConsent(preview, file: text, source: source, format: format);
      }
    } on ImportRejected catch (e) {
      _outcome.value = _Rejected(e.reason, source: source);
    } on UnreadableExport catch (e) {
      _outcome.value = _Rejected(null, source: source, newer: e.reason == .newer);
    } on ImportParked catch (e) {
      _outcome.value = _Parked(e.reason);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }

  /// A Heart file is JSON or CSV, and the export writes both; which one was
  /// picked is in its first character, whatever its name says. Every other
  /// source is a CSV.
  static _Format _formatOf(ImportSource source, String file) {
    return switch ((source, file.trimLeft().startsWith('{'))) {
      (.heart, true) => .json,
      _ => .csv,
    };
  }

  /// The app's own dry run, as the shape the server's comes in — the consent
  /// step and its counts are the same either way.
  static WorkoutImportPreview _asPreview(LocalImportPreview preview) {
    return WorkoutImportPreview(
      workoutsFound: preview.workoutsFound,
      workoutsAlreadyImported: preview.workoutsAlreadyHere,
      setsFound: preview.setsFound,
      exercisesMatched: preview.exercisesMatched,
      exercisesUnmatched: preview.exercisesUnmatched,
      rowsSkipped: preview.rowsSkipped,
    );
  }

  /// How many exercise names the preview could not resolve. Zero until one
  /// has run, which is the only way [_commit] is ever reached.
  int _unmatchedInPreview = 0;

  /// The commit half. [createCustom] carries the user's decision (absent when
  /// the preview found nothing to decide); sets on a declined name are
  /// skipped and come back counted in the report.
  Future<void> _commit(
    String file, {
    required ImportSource source,
    required _Format format,
    List<String>? createCustom,
  }) async {
    buzz();
    final messenger = ScaffoldMessenger.of(context);

    Analytics.of(context).dataImported(
      source: source.name,
      format: format.name,
      unmatched: _unmatchedInPreview,
      createdCustom: createCustom?.length ?? 0,
    );

    startLoading();
    // drops the consent card, so its button cannot double-submit while the
    // upload is in flight
    _outcome.value = null;
    try {
      _outcome.value = switch (format) {
        .csv => await _upload(file, source: source, createCustom: createCustom),
        .json => await _read(file, createCustom: createCustom),
      };
    } on ImportRejected catch (e) {
      _outcome.value = _Rejected(e.reason, source: source);
    } on UnreadableExport catch (e) {
      _outcome.value = _Rejected(null, source: source, newer: e.reason == .newer);
    } on ImportParked catch (e) {
      _outcome.value = _Parked(e.reason);
    } catch (e, s) {
      widget.onError?.call(e, stacktrace: s);
      messenger.snack(e.toString());
    } finally {
      stopLoading();
    }
  }

  /// A CSV: the server imports it, and the mirrors come down after.
  Future<_ImportOutcome> _upload(String csv, {required ImportSource source, List<String>? createCustom}) async {
    final workouts = Workouts.of(context);
    final exercises = Exercises.of(context);
    final backfill = Backfill.of(context);
    final dataImport = DataImport.of(context);
    final userId = Auth.of(context).user?.id;
    // what the store holds before the import, for the RPE offer to compare
    // against once its workouts are down
    final ratedBefore = switch (userId) {
      String uid => await dataImport.ratedSets(uid),
      null => 0,
    };

    final report = await Api.instance.importWorkouts(
      csv,
      source: source,
      unit: _exportUnit(source),
      tzOffset: _exportOffset(source),
      createCustom: createCustom,
    );
    // The imported workouts exist server-side only until the mirrors
    // refresh. Fire and forget: the report is the confirmation. The chain is
    // ordered like startup (see app.dart): history rows hold a foreign key
    // onto `exercises.name`, and an import that created custom exercises must
    // land them in the catalog before the mirror writes workouts that
    // reference them.
    //
    // [Backfill.resync] last, and it is what brings the *whole* import down:
    // `initHistory` only ever asks for the newest page, and this device's
    // mark was earned against the account as it stood before the import
    // (heart-of-yours#113).
    //
    // Only then can the store say whether the import brought ratings: the
    // report counts workouts and sets, not RPEs (#244).
    final outcome = _Imported(report);
    unawaited(
      exercises
          .init()
          .then((_) => workouts.initHistory())
          .then(
            (_) => switch (userId) {
              String uid => backfill.resync(uid).then((_) => _noticeRatings(outcome, uid, ratedBefore, dataImport)),
              null => null,
            },
          )
          .catchError(
            (e, s) => widget.onError?.call(e, stacktrace: s),
          ),
    );
    return outcome;
  }

  /// Opens the RPE offer's slot when [uid]'s store holds more rated sets than
  /// the [before] counted ahead of the import — unless the page has moved on
  /// from [outcome] by then: closed, or another file picked.
  Future<void> _noticeRatings(_Imported outcome, String uid, int before, DataImport dataImport) async {
    final after = await dataImport.ratedSets(uid);
    if (!mounted || !identical(_outcome.value, outcome)) return;
    if (after > before) _ratingsArrived.value = true;
  }

  /// Heart's own JSON: the app reads it into the store, then shows it.
  ///
  /// With an account the store is then owed a replay, exactly as after a
  /// sign-in, and [Upsync] carries what landed to the server with its
  /// progress line on the profile. The debt is recorded before anything is
  /// read back, because reading back runs the sweeps, which would post the
  /// imported workouts ahead of the custom exercises they name.
  Future<_ImportOutcome> _read(String file, {List<String>? createCustom}) async {
    final dataImport = DataImport.of(context);
    final auth = Auth.of(context);
    final upsync = Upsync.of(context);
    final exercises = Exercises.of(context);
    final templates = Templates.of(context);
    final workouts = Workouts.of(context);
    final goals = Goals.of(context);
    final previous = PreviousExercises.of(context);
    final stats = Stats.of(context);
    final uid = switch (auth.user?.id) {
      String id => id,
      null => throw StateError('an import with no session to import into'),
    };

    final ratedBefore = await dataImport.ratedSets(uid);
    final report = await dataImport.import(file, uid, createCustom: createCustom);
    // the store is what the file was read into, so it can answer at once
    final ratingsArrived = await dataImport.ratedSets(uid) > ratedBefore;

    final account = !auth.isAnonymous;
    if (account) await upsync.claim(from: uid, to: uid);
    unawaited(
      exercises
          .init()
          .then((_) => Future.wait([templates.init(), workouts.initHistory(), goals.init()]))
          .then((_) => Future.wait([previous.init(), stats.init()]))
          .then((_) => account ? upsync.run(uid) : null)
          .catchError(
            (e, s) => widget.onError?.call(e, stacktrace: s),
          ),
    );

    if (mounted) _ratingsArrived.value = ratingsArrived;
    return _Imported(
      WorkoutImportReport(
        workoutsFound: report.workoutsFound,
        workoutsCreated: report.workoutsCreated,
        workoutsSkipped: report.workoutsSkipped,
        setsCreated: report.setsCreated,
        setsSkipped: report.setsSkipped,
        exercisesMatched: report.exercisesMatched,
        exercisesCreated: report.exercisesCreated,
        exercisesSkipped: report.exercisesSkipped,
        rowsSkipped: report.rowsSkipped,
      ),
      alongside: (templates: report.templates, folders: report.folders, goals: report.goals),
    );
  }
}

/// The one ask for RPE (#244), under the report of an import that brought
/// rated sets. An import is the one moment the app learns that this user rates
/// sets, so that is where it asks; the ask itself follows `docs/opt-in.md`
/// like every other: once, then the one notice on a no, and nothing at all
/// when RPE is already on or already declined.
class const _ImportRpeOffer({required final ValueListenable<bool> ratingsArrived}) extends StatelessWidget {
  static const _feature = Feature.rpe;

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final L(:rpeImportOfferTitle, :rpeImportOfferBody) = L.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: ratingsArrived,
      builder: (context, arrived, _) {
        final Widget? child = switch (preferences) {
          _ when !arrived => null,
          _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
            onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
          ),
          _ when preferences.shouldOffer(_feature) => FeatureOffer(
            key: AppKeys.rpeImportOffer,
            acceptKey: AppKeys.rpeImportAccept,
            declineKey: AppKeys.rpeImportDecline,
            icon: _feature.icon,
            title: rpeImportOfferTitle,
            body: rpeImportOfferBody,
            onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
            onShown: () => preferences.markOffered(_feature),
          ),
          _ => null,
        };

        return switch (child) {
          Widget child => Padding(
            padding: const .only(top: 24),
            child: child,
          ),
          null => const SizedBox.shrink(),
        };
      },
    );
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
                    visualDensity: .compact,
                    // a slim inset keeps the ink from running flush against
                    // the text column; the shape rounds it like the pickers
                    contentPadding: const .symmetric(horizontal: 8),
                    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
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
                backgroundColor: colorScheme.surfaceContainerHighest,
                margin: const .symmetric(horizontal: 8.0, vertical: 14),
                onPressed: widget.onCancel,
                child: Center(
                  child: Text(cancel),
                ),
              ),
            ),
            Expanded(
              child: PrimaryButton.wide(
                margin: const .symmetric(horizontal: 8.0, vertical: 14),
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
  final ({int templates, int folders, int goals})? alongside;

  const new({required this.report, this.alongside});

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
      :importedTemplates,
      :importedFolders,
      :importedGoals,
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
        if (alongside case (:final templates, :final folders, :final goals)) ...[
          if (templates > 0) Text(importedTemplates(templates)),
          if (folders > 0) Text(importedFolders(folders)),
          if (goals > 0) Text(importedGoals(goals)),
        ],
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
  final ImportSource source;
  final bool newer;

  const new({required this.reason, required this.source, this.newer = false});

  @override
  Widget build(BuildContext context) {
    final L(
      :importFailedHeadline,
      :importFailedBody,
      :importFailedBodyHevy,
      :importFailedBodyHeart,
      :importFailedBodyNewer,
    ) = L.of(
      context,
    );
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
        Text(
          switch ((source, newer)) {
            (_, true) => importFailedBodyNewer,
            (.strong, _) => importFailedBody,
            (.hevy, _) => importFailedBodyHevy,
            (.heart, _) => importFailedBodyHeart,
          },
        ),
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

/// The file was kept for a person to import (#324). Not an error — nothing
/// for the user to fix or retry — so the headline is the outcome, not a
/// failure, and the server's reason stays detail text as on a rejection.
class _ImportParkedView extends StatelessWidget {
  final String? reason;

  const new({required this.reason});

  @override
  Widget build(BuildContext context) {
    final L(:importParkedHeadline, :importParkedBody) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              Icons.schedule_rounded,
              color: colorScheme.primary,
            ),
            Text(
              importParkedHeadline,
              style: textTheme.titleMedium,
            ),
          ],
        ),
        Text(importParkedBody),
        if (reason case String detail)
          Text(
            detail,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
      ],
    );
  }
}
