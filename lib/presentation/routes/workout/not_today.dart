part of 'workout.dart';

/// "Not today" (#312) under the new-workout button: one tap sets today aside,
/// and the sheet after it offers a reason and Undo. Once today is set aside it
/// says so, with its own Undo, and asks nothing. Absent while a workout is
/// running: the user is training.
class _NotToday extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final programs = Programs.watch(context);
    final training = context.select<Workouts, bool>((workouts) => workouts.hasActiveWorkout);
    if (training) return const SliverToBoxAdapter();

    final now = DateTime.now();
    final today = programs.skips.where((skip) => skip.isDay && DateUtils.isSameDay(skip.at.toLocal(), now)).lastOrNull;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const .symmetric(horizontal: 8),
        child: Align(
          alignment: .centerRight,
          child: switch (today) {
            null => TextButton.icon(
              key: AppKeys.notTodayDay,
              onPressed: () => _setAside(context),
              icon: const Icon(Icons.redo_rounded, size: 18),
              label: Text(copy.programNotToday),
            ),
            final TrainingSkip skip => Row(
              mainAxisSize: .min,
              spacing: 4,
              children: [
                Text(copy.notTodayDay, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                TextButton(
                  key: AppKeys.notTodayUndo,
                  onPressed: () {
                    Analytics.of(context).programUnskipped();
                    programs.unskip(skip);
                  },
                  child: Text(copy.undo),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  Future<void> _setAside(BuildContext context) async {
    final copy = L.of(context);
    Analytics.of(context).daySkipped();
    final skip = await Programs.of(context).skipDay();
    if (!context.mounted) return;
    await showSkipSheet(context, skip, title: copy.notTodayDay);
  }
}

/// The one ask for "Not today" (#445, `docs/opt-in.md`), where the day's
/// button would be: the first time a session of a program on the user's own
/// days went by undone, with nothing since. That is the moment the feature
/// would first have had something to say, and until then nobody is asked.
/// A yes puts the button here in its place; a no earns the one notice, and
/// after that the Workout tab is as it was before the feature existed.
///
/// Absent while a workout is running, as the button is: the user is training.
class _NotTodayOffer extends StatelessWidget {
  static const _feature = Feature.notToday;

  const new();

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final preferences = Preferences.watch(context);
    final training = context.select<Workouts, bool>((workouts) => workouts.hasActiveWorkout);

    final Widget? child = switch (preferences) {
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when training => null,
      // an offer already up stays up for the session, whatever became of
      // the session that raised it
      _ when preferences.shouldOffer(_feature) && (_offered(preferences) || _undone(context)) => FeatureOffer(
        key: AppKeys.notTodayOffer,
        acceptKey: AppKeys.notTodayAccept,
        declineKey: AppKeys.notTodayDecline,
        icon: _feature.icon,
        title: copy.notTodayOfferTitle,
        body: copy.notTodayOfferBody,
        onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => null,
    };

    return SliverToBoxAdapter(
      child: switch (child) {
        final Widget child => Padding(padding: const .fromLTRB(8, 8, 8, 0), child: child),
        null => null,
      },
    );
  }

  static bool _offered(Preferences preferences) => preferences.featureAnswer(_feature) == FeatureAnswer.pending;

  /// Whether a program the user follows, and is shown, has a preferred day
  /// behind it with its session undone.
  static bool _undone(BuildContext context) {
    final programs = Programs.watch(context);
    final now = DateTime.now();
    final firstWeekday = firstWeekdayOf(context, listen: true);
    return shownPrograms(context, listen: true).following.any(
      (program) => programs.undoneDayOf(program, now: now, firstWeekday: firstWeekday) != null,
    );
  }
}
