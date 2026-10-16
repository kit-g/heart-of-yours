part of 'history.dart';

/// A day set aside with "Not today" (#312), on a page of its own: what a
/// calendar event's link opens when its session was skipped (#391), and what a
/// skip's row in History opens. The session, its program and the day, and the
/// way on to the program.
class SkipPage extends StatelessWidget {
  final String skipId;
  final ValueChanged<String> onOpenProgram;

  /// Empties the two-pane detail. Null in compact, where the page is pushed and
  /// popping it is the right thing.
  final VoidCallback? onClose;

  const new({super.key, required this.skipId, required this.onOpenProgram, this.onClose});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final programs = Programs.watch(context);
    final skip = programs.skips.where((skip) => skip.id == skipId).firstOrNull;
    final leading = switch (onClose) {
      final VoidCallback close => IconButton(
        key: AppKeys.closeDetail,
        tooltip: copy.close,
        onPressed: close,
        icon: const Icon(Icons.close),
      ),
      null => null,
    };
    // taken back, or not read yet; and a skip whose feature is off is one
    // the app has no page for
    final preferences = Preferences.watch(context);
    final shown = switch (skip?.isDay) {
      true => preferences.isOn(.notToday),
      false => preferences.isOn(.programs),
      null => false,
    };
    if (skip == null || !shown) {
      return Scaffold(appBar: AppBar(leading: leading));
    }

    final session = switch (skip.templateId) {
      final String id => Templates.watch(context).lookup(id)?.name,
      null => null,
    };
    final program = switch (skip.programId) {
      final String id => programs.lookup(id),
      null => null,
    };
    final muted = textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(leading: leading, title: Text(copy.programNotToday)),
      body: SafeArea(
        child: Align(
          alignment: .topCenter,
          // a few lines of prose: a measure, not a tablet pane's width
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readableWidth),
            child: ListView(
              key: AppKeys.skipPage,
              padding: const .all(16),
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Icon(Icons.redo_rounded, color: colorScheme.outline),
                    Expanded(
                      child: Text(
                        session ?? copy.programNotToday,
                        style: textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(DateFormat.yMMMMEEEEd(copy.localeName).format(skip.at.toLocal()), style: muted),
                if (SkipReason.of(skip.reason) case final SkipReason reason) ...[
                  const SizedBox(height: 4),
                  Text(reason.label(copy), style: muted),
                ],
                if (program case Program(:final name, :final String id)) ...[
                  const SizedBox(height: 4),
                  Text(name, style: muted),
                  const SizedBox(height: 24),
                  Align(
                    alignment: .centerLeft,
                    child: PrimaryButton.shrunk(
                      key: AppKeys.skipOpenProgram,
                      onPressed: () => onOpenProgram(id),
                      child: Text(copy.programOpen),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _ThatDay(key: ValueKey(skip.id), at: skip.at),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the day looked like when it was set aside (#312): the training before
/// it, read from History, and what Health has for it. Worked out from what this
/// phone holds rather than stored with the skip, so nothing of it syncs, and
/// the Health part is the device's mirror, shown and never kept anywhere else
/// (`docs/2026-09-05.health-data.md`). Weather joins it with #310.
class _ThatDay extends StatefulWidget {
  final DateTime at;

  const new({super.key, required this.at});

  @override
  State<_ThatDay> createState() => _ThatDayState();
}

class _ThatDayState extends State<_ThatDay> {
  /// The four weeks before the skip: far enough back to say how long it had
  /// been, and to hold the week and the two days the lines below read.
  late final Future<List<LensSets>> _before = Stats.of(
    context,
  ).getLensSets(widget.at.subtract(const Duration(days: 28)), widget.at);

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final health = Health.watch(context);
    final preferences = Preferences.watch(context);
    final day = widget.at.toLocal();
    final readings = [
      for (final metric in _body)
        if (health[metric].where((each) => DateUtils.isSameDay(each.day, day)).lastOrNull case (:final value, day: _))
          (metric, metric.display(value, preferences, copy)),
    ];

    return FutureBuilder<List<LensSets>>(
      future: _before,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <LensSets>[];
        final last = rows
            .map((row) => row.start)
            .fold<DateTime?>(
              null,
              (latest, start) => switch (latest) {
                final DateTime latest when latest.isAfter(start) => latest,
                _ => start,
              },
            );
        final week = widget.at.subtract(const Duration(days: 7));
        final recent = widget.at.subtract(const Duration(hours: 48));
        final sets = rows.where((row) => row.start.isAfter(week)).fold(0, (sum, row) => sum + row.sets);
        final recovering = {
          for (final row in rows.where((row) => row.start.isAfter(recent))) ...muscleGroupsOf(row).keys,
        };

        return Column(
          key: AppKeys.skipThatDay,
          crossAxisAlignment: .start,
          spacing: 4,
          children: [
            Text(copy.skipThatDay, style: textTheme.titleSmall),
            switch (last) {
              final DateTime last => Text(
                copy.skipDaysSince(DateUtils.dateOnly(day).difference(DateUtils.dateOnly(last.toLocal())).inDays),
              ),
              null => Text(copy.skipNoWorkoutBefore),
            },
            Text(copy.skipSetsWeek(sets)),
            if (recovering.isNotEmpty)
              Text(copy.skipRecovering(recovering.map((group) => group.label(copy)).join(', '))),
            if (readings.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final (metric, (number, unit)) in readings)
                Text(
                  [
                    metric.label(copy),
                    number,
                    ?switch (unit) {
                      '' => null,
                      final String unit => unit,
                    },
                  ].join(' '),
                ),
              Text(copy.skipFromHealth, style: muted),
            ],
          ],
        );
      },
    );
  }

  /// What Health can say about a day someone chose not to train.
  static const _body = [
    HealthMetric.sleepAsleep,
    HealthMetric.heartRateVariability,
    HealthMetric.restingHeartRate,
    HealthMetric.steps,
  ];
}
