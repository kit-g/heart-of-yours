part of 'workout_detail.dart';

const _fixedColumnWidth = 32.0;

/// The set column, which is wider than the number it holds.
///
/// Its header is a *word* — "Set" fits in a number's worth of space, "Serie"
/// and "Подход" do not, and at 32pt Spanish came out as "Seri / e". The column
/// is sized for the header and the chip follows it, so the number stays
/// centred under its own label. [_ColumnLabel] catches whatever still does not
/// fit.
const _setColumnWidth = 44.0;
const _fixedButtonHeight = 24.0;
const _emptyValue = '-';

final _floatingPointFormatters = <TextInputFormatter>[
  const NDigitFloatingPointFormatter(),
  FilteringTextInputFormatter.singleLineFormatter,
];

final _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

extension on TextEditingController {
  void selectAllText() {
    selection = TextSelection(
      baseOffset: 0,
      extentOffset: value.text.length,
    );
  }
}

enum _ExerciseOption { inspectExercise, autoRestTimer, remove }

/// Index in [items] where [dragged] would land if dropped on [hovered] — the
/// slot the drop indicator marks, and the slot the reorder actually produces.
///
/// A downwards drag lands *after* [hovered], an upwards drag *before* it, which
/// is what makes dropping onto the neighbour directly below do something: a
/// plain insert-before would put the exercise back where it already was.
/// A null [hovered] means the trailing target, i.e. append.
///
/// Returns null when there is nothing to draw or move.
int? dropIndex(List<WorkoutExercise> items, WorkoutExercise? dragged, WorkoutExercise? hovered) {
  if (dragged == null) return null;
  if (hovered == null) return items.length;

  final from = items.indexOf(dragged);
  final to = items.indexOf(hovered);

  if (from < 0 || to < 0 || from == to) return null;

  return switch (from < to) {
    true => to + 1,
    false => to,
  };
}

Future<void> showFinishWorkoutDialog(BuildContext context, Workouts workouts, {VoidCallback? onFinish}) async {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final Workouts(:activeWorkout) = workouts;
  final Workout(:isValid, :isStarted) = activeWorkout!;
  final L(
    :cancel,
    :finish,
    :finishWorkoutTitle,
    :finishWorkoutBody,
    :finishWorkoutWarningTitle,
    :finishWorkoutWarningBody,
    :readyToFinish,
    :notReadyToFinish,
    :untickedSetsTitle,
    :untickedSetsBody,
    :saveUntickedSets,
    :discardUntickedSets,
  ) = L.of(
    context,
  );

  /// Finishes, and tells the caller it has.
  void finishNow() {
    Navigator.of(context, rootNavigator: true).pop();
    finishWorkout(context, workouts);
    onFinish?.call();
  }

  final actions = [
    Column(
      spacing: 8,
      children: [
        PrimaryButton.wide(
          backgroundColor: colorScheme.surfaceContainerHighest,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Center(
            child: Text(notReadyToFinish),
          ),
        ),
        PrimaryButton.wide(
          onPressed: finishNow,
          child: Center(
            child: Text(readyToFinish),
          ),
        ),
      ],
    ),
  ];

  if (isValid) {
    return showBrandedDialog(
      context,
      title: Text(finishWorkoutTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.check_circle_outline_rounded,
        color: colorScheme.onPrimaryContainer,
      ),
      content: Text(
        finishWorkoutBody,
        textAlign: .center,
      ),
      actions: actions,
    );
  }

  // Sets carrying values that were never ticked. Whether they count is the
  // user's call and nobody else's: completing them silently credits a session
  // somebody may only have planned, and dropping them silently is how a typed
  // set used to vanish. So the finish asks, in as many words, and the two
  // answers are both spelled out.
  if (workouts.hasTypedButUntickedSets) {
    return showBrandedDialog(
      context,
      title: Text(untickedSetsTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.checklist_rounded,
        color: colorScheme.error,
      ),
      content: Text(
        untickedSetsBody,
        textAlign: .center,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: Center(child: Text(notReadyToFinish)),
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              onPressed: finishNow,
              child: Center(child: Text(discardUntickedSets)),
            ),
            PrimaryButton.wide(
              child: Center(child: Text(saveUntickedSets)),
              onPressed: () {
                workouts.completeTypedSets();
                finishNow();
              },
            ),
          ],
        ),
      ],
    );
  }

  // Not "did a set get ticked" but "would finishing keep anything": a set typed
  // and left unticked counts, and used to fall through to the cancel dialog —
  // the only way out of which is discarding the session (#F3).
  if (isStarted || workouts.activeWorkoutHasContent) {
    return showBrandedDialog(
      context,
      title: Text(finishWorkoutWarningTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.error,
      ),
      content: Text(
        finishWorkoutWarningBody,
        textAlign: .center,
      ),
      actions: actions,
    );
  }

  return showCancelWorkoutDialog(context, onFinish: onFinish);
}

Future<void> showCancelWorkoutDialog(BuildContext context, {VoidCallback? onFinish}) {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final L(
    :cancelWorkoutBody,
    :cancelWorkoutTitle,
    :cancelWorkout,
    :resumeWorkout,
  ) = L.of(
    context,
  );
  return showBrandedDialog(
    context,
    title: Text(cancelWorkoutTitle),
    titleTextStyle: textTheme.titleMedium,
    content: Text(
      cancelWorkoutBody,
      textAlign: .center,
    ),
    icon: Icon(
      Icons.error_outline_rounded,
      color: colorScheme.error,
    ),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(resumeWorkout),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          PrimaryButton.wide(
            backgroundColor: colorScheme.errorContainer,
            child: Center(
              child: Text(
                cancelWorkout,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).maybePop();
              cancelAllNotifications();
              Workouts.of(context).cancelActiveWorkout();
              onFinish?.call();
            },
          ),
        ],
      ),
    ],
  );
}

/// Starts a workout through [start] — asking first when one is already going
/// (#228). Every way into a new workout comes through here: the user confirms
/// discarding the active one, and it is cancelled (deleted) before [start]
/// runs, so the old one can never be left behind half-alive. Completes with
/// whether [start] ran.
Future<bool> startWorkoutOverActive(BuildContext context, Future<void> Function() start) async {
  final workouts = Workouts.of(context);
  if (workouts.hasActiveWorkout) {
    final discard = await _showDiscardActiveWorkoutDialog(context);
    if (discard != true) return false;
    cancelAllNotifications();
    await workouts.cancelActiveWorkout();
  }
  await start();
  return true;
}

Future<bool?> _showDiscardActiveWorkoutDialog(BuildContext context) {
  final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
  final L(:cancelCurrentWorkoutTitle, :cancelCurrentWorkoutBody, :keepCurrentAccount, :cancelAndStartNewWorkout) = L.of(
    context,
  );
  return showBrandedDialog<bool>(
    context,
    title: Text(cancelCurrentWorkoutTitle, textAlign: .center),
    content: Text(cancelCurrentWorkoutBody, textAlign: .center),
    icon: Icon(Icons.error_outline_rounded, color: colorScheme.error),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Center(child: Text(keepCurrentAccount, textAlign: .center)),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
          ),
          PrimaryButton.wide(
            key: WorkoutDetailKeys.discardAndStart,
            backgroundColor: colorScheme.errorContainer,
            child: Center(
              child: Text(
                cancelAndStartNewWorkout,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                textAlign: .center,
              ),
            ),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          ),
        ],
      ),
    ],
  );
}

/// Finishes the active workout: saves it, mirrors it to Health, and shows its
/// summary. The one finish path — the phone's dialog calls it once the user
/// confirmed, and so does the watch's Finish (#183), which confirmed on the
/// wrist. [context] needs no route of its own: navigation goes through
/// [HeartRouter].
Future<void> finishWorkout(BuildContext context, Workouts workouts, {DateTime? at}) {
  workouts.activeWorkout?.resolveName(L.of(context).defaultWorkoutName());

  // Read before navigating: the screen this context belongs to is on its way
  // out, and the mirror below runs long after it has gone.
  final health = Health.of(context);

  // Whether Heart may put a permission sheet in front of this user. True only
  // once they have engaged with health at all — someone who never accepted the
  // invitation should not meet a Health prompt because they finished a workout.
  // See [Health.recordWorkout].
  final mayAsk = Preferences.of(context).healthAsked(health.userId);

  // The watch app, if it is on (#184): read here for the same reason as health.
  final watch = switch (Preferences.of(context).isOn(.watchApp)) {
    true => watchLink(Theme.of(context).platform),
    _ => null,
  };

  // **The session this device holds, not the one the finish resolves to.**
  //
  // `finishActiveWorkout` completes with the server's copy, because the server
  // mints the id anything referring to the session afterwards must use. Its
  // embedded exercises are not the catalogue's, though: they arrive without the
  // library's health annotation, so reading the activity off them labelled
  // every swim `other` in the Health app. Caught on a simulator, with the
  // annotation sitting correctly in the local catalogue the whole time.
  //
  // This object is the one `finish()` mutates in place, so by the time the
  // future below runs it carries the same start and end — and the exercises the
  // user actually picked.
  final session = workouts.activeWorkout;

  HeartRouter.of(context).goToWorkoutDone(workouts.activeWorkout?.id);
  cancelAllNotifications();

  // Told before the finish, not after it: the finish clears the active workout,
  // the watch hears "no workout" at once, and a workout session that ends
  // without being told it was finished is thrown away as a cancel. The answer
  // is whether the watch measured this session — then it saves the workout, and
  // the phone must not write a second, unmeasured one beside it.
  final measured = switch ((watch, session)) {
    (WatchLink watch, Workout session) => watch.finish(session.id, end: at ?? DateTime.now()),
    _ => Future.value(false),
  };

  final finishing = workouts.finishActiveWorkout(at: at);

  // "last time" and the picker's recency both read the finished session out
  // of the mirror; until this they kept the launch's view all session long
  final previous = PreviousExercises.of(context);
  unawaited(finishing.then((_) => previous.init()));

  // Mirror the session into the device's health store — deliberately not
  // awaited. The user is already looking at the summary screen, and whether
  // HealthKit accepted a courtesy copy is not something a finished workout
  // should wait on, let alone fail on.
  //
  // Chained off the finish rather than fired beside it, so the write sees an
  // ended workout with its empty sets already dropped.
  unawaited(
    finishing.then(
      (_) async {
        if (session case Workout finished when !await measured) {
          // The name is copy, and this is the layer that owns it.
          await health.recordWorkout(finished, title: finished.name, mayAsk: mayAsk);
        }
      },
    ),
  );

  return finishing;
}

Future<void> showDeleteImageDialog(
  BuildContext context,
  Workout workout,
  WorkoutImage image, {
  required Future<void> Function(BuildContext context) onDeleted,
}) {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final L(
    :deleteImageDialogBody,
    :deleteImageDialogTitle,
    :cancel,
    :removePhoto,
  ) = L.of(
    context,
  );
  return showBrandedDialog(
    context,
    title: Text(deleteImageDialogTitle),
    titleTextStyle: textTheme.titleMedium,
    content: Text(
      deleteImageDialogBody,
      textAlign: .center,
    ),
    icon: Icon(
      Icons.delete_forever,
      color: colorScheme.error,
    ),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(cancel),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          PrimaryButton.wide(
            backgroundColor: colorScheme.errorContainer,
            child: Center(
              child: Text(
                removePhoto,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
            onPressed: () => onDeleted(context),
          ),
        ],
      ),
    ],
  );
}
