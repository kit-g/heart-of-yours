part of 'exercises.dart';

/// Whether [source]'s menu offers to move its history (#338): the page was
/// given somewhere to go afterwards, there is an account to move it on, and the
/// workout in progress, if any, does not hold [source]. That workout lives on
/// the device alone: its sets would save under [source] once the history had
/// left it, and fail outright where the move deleted it. [listen] is for a
/// build, so adding [source] to the workout takes the offer away.
bool _canMoveHistory(
  BuildContext context,
  Exercise source, {
  required void Function(Exercise)? onMoved,
  bool listen = false,
}) {
  if (onMoved == null) return false;
  final workouts = listen ? Workouts.watch(context) : Workouts.of(context);
  final holdsSource = switch (workouts.activeWorkout) {
    null => false,
    final workout => workout.any((each) => each.exercise.id == source.id),
  };
  return Exercises.of(context).canMoveHistory && !holdsSource;
}

/// Whether [target]'s sets can hold [source]'s as they were logged: the same
/// columns, so an ab wheel's reps never land on a ride's distance and time, and
/// an assisted weight only where weight means assistance, never added load.
bool _holdsHistoryOf(Exercise target, Exercise source) {
  return listEquals(SetColumn.of(target.category), SetColumn.of(source.category)) &&
      (target.category == .assistedBodyWeight) == (source.category == .assistedBodyWeight);
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

  final target = await showSingleExercisePicker(
    context,
    except: source.id,
    refuses: (exercise) => switch (_holdsHistoryOf(exercise, source)) {
      true => null,
      false => copy.moveHistoryIncompatible(exercise.name, source.name),
    },
  );
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
  final programs = Programs.of(context);

  try {
    await exercises.moveHistory(source, target);
  } on ExerciseMoveRefused catch (refused) {
    messenger.snack(_refusal(copy, refused.reason, source: source, target: target));
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
  // rules, ladders, advances, bases and share targets (heart-api#226)
  unawaited(programs.reread());
}

/// Why the server refused to move [source]'s history onto [target]. The app
/// never asks for the same exercise twice, so that refusal, like an unknown
/// one, means an exercise has gone from the account since the page read it.
/// An incompatible one means the two have drifted apart since: a category
/// changed on another device.
String _refusal(L copy, ExerciseMoveRefusal reason, {required Exercise source, required Exercise target}) {
  return switch (reason) {
    .sameExercise || .unknownExercise => copy.moveHistoryGone,
    .incompatibleExercise => copy.moveHistoryIncompatible(target.name, source.name),
  };
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
          AsyncSnapshot(error: ExerciseMoveRefused(:final reason)) => [
            _refusal(copy, reason, source: source, target: target),
          ],
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
