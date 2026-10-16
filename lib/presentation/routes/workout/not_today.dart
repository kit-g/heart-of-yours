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
