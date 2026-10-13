part of 'exercises.dart';

/// Whether an exercise's menu offers to move its history (#338): the page was
/// given somewhere to go afterwards, there is an account to move it on, and no
/// workout is in progress — that one lives on the device alone, and would go
/// on naming an exercise the move may delete.
bool _canMoveHistory(BuildContext context, {required void Function(Exercise)? onMoved}) {
  if (onMoved == null) return false;
  return Exercises.of(context).canMoveHistory && !Workouts.of(context).hasActiveWorkout;
}

/// Moves [source]'s history onto an exercise the user picks: the target, then
/// what the move would do, then the move. [onMoved] is handed the target once
/// the history is there.
Future<void> _onMoveHistory(
  BuildContext context,
  Exercise source, {
  required void Function(Exercise target) onMoved,
}) async {
  final exercises = Exercises.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final copy = L.of(context);

  final target = await showSingleExercisePicker(context, except: source.id);
  if (target == null || !context.mounted) return;

  // started now, and read by the dialog once it is up: its failure is the
  // dialog's to show, never an unhandled error in the meantime
  final preview = exercises.previewMove(source, target)..ignore();
  final confirmed = await showBrandedDialog<bool>(
    context,
    title: Text(copy.moveHistoryTitle(target.name), textAlign: .center),
    content: _MovePreview(preview: preview, source: source, target: target),
  );
  if (confirmed != true || !context.mounted) return;

  // everything that reads the mirror, gathered while the page is still here
  final templates = Templates.of(context);
  final workouts = Workouts.of(context);
  final timers = Timers.of(context);
  final goals = Goals.of(context);
  final charts = Charts.of(context);
  final previous = PreviousExercises.of(context);

  try {
    await exercises.moveHistory(source, target);
  } on ExerciseMoveRefused {
    messenger.snack(copy.moveHistoryGone);
    return;
  } catch (e, s) {
    reportToSentry(e, stacktrace: s);
    messenger.snack(copy.moveHistoryFailed);
    return;
  }

  // before the source's page can rebuild over an exercise that may be gone
  onMoved(target);
  messenger.snack(copy.moveHistoryDone(target.name));

  // the mirror was re-keyed under every one of these
  unawaited(templates.reread());
  unawaited(workouts.reread(source.id));
  unawaited(timers.init());
  unawaited(goals.init());
  unawaited(charts.reload());
  unawaited(previous.init());
}

/// What the move would do, as the server's dry run counts it, and the Move
/// button once it has. A preview that fails says so, and offers nothing.
class _MovePreview extends StatelessWidget {
  final Future<ExerciseMoveReport> preview;
  final Exercise source;
  final Exercise target;

  const new({required this.preview, required this.source, required this.target});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return FutureBuilder<ExerciseMoveReport>(
      future: preview,
      builder: (context, snapshot) {
        final lines = switch (snapshot) {
          AsyncSnapshot(hasData: true, :final data!) => [
            ..._counts(copy, data),
            if (data.preferencesDropped > 0) copy.moveHistoryPreferenceDropped(target.name, source.name),
            if (data.sourceDeleted) copy.moveHistorySourceDeleted(source.name),
            copy.moveHistoryFinal,
          ],
          AsyncSnapshot(error: ExerciseMoveRefused()) => [copy.moveHistoryGone],
          AsyncSnapshot(hasError: true) => [copy.moveHistoryFailed],
          _ => null,
        };

        return Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            switch (lines) {
              null => const Padding(
                padding: .all(16),
                child: CircularProgressIndicator.adaptive(),
              ),
              List<String> lines => Text(lines.join('\n'), textAlign: .center),
            },
            const SizedBox(height: 4),
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Center(child: Text(copy.cancel)),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
            ),
            if (snapshot.hasData)
              PrimaryButton.wide(
                backgroundColor: colorScheme.errorContainer,
                child: Center(
                  child: Text(
                    copy.moveHistoryAction,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                  ),
                ),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
              ),
          ],
        );
      },
    );
  }

  /// One line of what moves, naming only what there is.
  static List<String> _counts(L copy, ExerciseMoveReport report) {
    final parts = [
      if (report.workoutExercises > 0) copy.moveHistoryLogged(report.workoutExercises),
      if (report.templateExercises > 0) copy.moveHistoryTemplates(report.templateExercises),
      if (report.goals > 0) copy.moveHistoryGoals(report.goals),
    ];
    return switch (parts) {
      [] => [copy.moveHistoryNothing],
      _ => [parts.join(' · ')],
    };
  }
}
