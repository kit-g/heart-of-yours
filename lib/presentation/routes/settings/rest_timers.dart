part of 'settings.dart';

/// Every exercise with a rest timer, what it is set to, and a way to change or
/// clear it — otherwise a timer is only visible from inside a workout, on the
/// exercise that owns it.
///
/// A view over [Timers]: nothing here is stored beyond what setting a timer
/// from the exercise menu already stores.
class RestTimersPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final L(:restTimers, :restTimersEmpty) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final exercises = Exercises.watch(context);
    // keyed by exercise id under a foreign key that cascades, so every timer
    // resolves; one that does not can only come from a hand-edited database,
    // and inventing a row for it would be answering a state the app cannot
    // reach
    final rows = [
      for (final MapEntry(key: id, value: seconds) in Timers.watch(context).all.entries)
        if (exercises.lookup(id) case Exercise exercise) (id: id, exercise: exercise, seconds: seconds),
    ]..sort((a, b) => a.exercise.name.toLowerCase().compareTo(b.exercise.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(restTimers),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: switch ((exercises.isInitialized, rows.isEmpty)) {
        // before the catalog lands nothing resolves, and the page would claim
        // there are no timers
        (false, _) => const SizedBox.shrink(),
        (true, true) => Center(
          child: Padding(
            padding: const .all(24),
            child: Text(
              restTimersEmpty,
              textAlign: .center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        (true, false) => _RestTimerList(rows: rows),
      },
    );
  }
}

typedef _Row = ({String id, Exercise exercise, int seconds});

class _RestTimerList extends StatelessWidget {
  final List<_Row> rows;

  const new({required this.rows});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // a name and a duration per row — across a tablet pane the two end up
        // too far apart to read as one line
        final width = math.min(constraints.maxWidth, readableWidth);
        return Align(
          alignment: .topCenter,
          child: SizedBox(
            width: width,
            child: ListView(
              padding: const .symmetric(vertical: 8),
              children: [
                ...rows.map((row) => _RestTimerTile(key: ValueKey(row.id), row: row)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RestTimerTile extends StatelessWidget with HasHaptic {
  final _Row row;

  const new({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final L(:clearRestTimerFor) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final (:exercise, :seconds, id: _) = row;

    return ListTile(
      // M3's default end inset is 24, and the clear button carries 12 more of
      // its own around the glyph — together they strand the ✕ well inside the
      // edge. 4 puts the glyph 16 in, level with the badge on the other side.
      contentPadding: const .only(left: 16, right: 4),
      // the name beside it already says which exercise this is; its label
      // would only have a screen reader say it twice
      leading: ExcludeSemantics(child: ExerciseBadge(exercise: exercise)),
      // wraps rather than ellipsizes: a long French or Russian name is the
      // whole point of the row
      title: Text(exercise.name),
      trailing: Row(
        mainAxisSize: .min,
        children: [
          Text(
            formatRestTimer(seconds),
            style: textTheme.bodyLarge?.copyWith(fontFeatures: const [.tabularFigures()]),
          ),
          IconButton(
            tooltip: clearRestTimerFor(exercise.name),
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _clear(context),
          ),
        ],
      ),
      onTap: () => _edit(context),
    );
  }

  Future<void> _edit(BuildContext context) async {
    buzz();
    final timers = Timers.of(context);
    final seconds = await showDurationPicker(
      context,
      initialValue: row.seconds,
      subtitle: L.of(context).forExercise(row.exercise.name),
    );

    // the picker's own contract, as the exercise menu reads it
    switch (seconds) {
      case 0: // its Cancel: no timer
        if (context.mounted) _clear(context);
      case int seconds when seconds > 0:
        timers.setRestTimer(row.id, seconds);
      default: // dismissed
    }
  }

  /// Cleared on the spot, with the way back held long enough to find — no
  /// confirmation for something this easy to undo.
  void _clear(BuildContext context) {
    buzz();
    final L(:restTimerCleared, :undo) = L.of(context);
    final timers = Timers.of(context);
    final (:id, :seconds, exercise: _) = row;

    timers.remove(id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..snack(
        restTimerCleared,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: undo,
          onPressed: () => timers.setRestTimer(id, seconds),
        ),
      );
  }
}
