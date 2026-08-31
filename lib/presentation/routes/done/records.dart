part of 'done.dart';

/// The personal records the session just set — max weight, estimated 1RM and
/// friends, per exercise. Plays by [_Achievements]' rules: nothing while it
/// resolves (the records are read back out of the database the finish is
/// still writing), and nothing at all when no record fell, which is most
/// sessions.
class _Records extends StatefulWidget {
  final Future<List<AchievedRecord>> Function() callback;

  const new({required this.callback});

  @override
  State<_Records> createState() => _RecordsState();
}

class _RecordsState extends State<_Records> {
  /// Resolved once, not per build — same reasoning as [_Achievements]:
  /// this widget watches providers for its copy and rebuilds on their
  /// notifications, and asking again would race the reveal.
  late final Future<List<AchievedRecord>> _achieved = widget.callback();

  static const _revealDuration = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    final exercises = Exercises.watch(context);

    return FutureBuilder<List<AchievedRecord>>(
      future: _achieved,
      builder: (_, snapshot) {
        final achieved = snapshot.data;

        return AnimatedSize(
          duration: _revealDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _revealDuration,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: switch (achieved) {
              null || [] => const SizedBox(width: double.infinity),
              _ => _recordsBlock(achieved, textTheme, colorScheme, l, prefs, exercises),
            },
          ),
        );
      },
    );
  }

  Widget _recordsBlock(
    List<AchievedRecord> achieved,
    TextTheme textTheme,
    ColorScheme colorScheme,
    L l,
    Preferences prefs,
    Exercises exercises,
  ) {
    // one line per exercise, its records strung together — a list of twelve
    // single-record lines reads as a ledger, not a celebration. Keyed by the
    // exercise itself: equality is the id, and the name is display copy.
    final byExercise = <Exercise, List<AchievedRecord>>{};
    for (final record in achieved) {
      (byExercise[record.exercise] ??= []).add(record);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 24, right: 24),
      child: Column(
        spacing: 8,
        children: [
          Text(
            l.recordsAchievedHeading(achieved.length),
            style: textTheme.titleMedium,
          ),
          for (final MapEntry(key: exercise, value: records) in byExercise.entries)
            Builder(
              builder: (context) {
                final formats = RecordFormats(l: l, prefs: prefs, unit: exercises.unitFor(exercise.id));
                return Text(
                  l.recordAchievedLine(
                    exercise.name,
                    records
                        .map(
                          (each) => '${recordKindLabel(context, each.kind)} ${formats.value(each.kind, each.record)}',
                        )
                        .join(' · '),
                  ),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                );
              },
            ),
        ],
      ),
    );
  }
}
