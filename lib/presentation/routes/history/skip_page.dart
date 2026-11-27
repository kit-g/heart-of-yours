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
    final program = switch (skip) {
      final TrainingSkip skip => programs.programOf(skip),
      null => null,
    };
    final shown = switch (skip) {
      TrainingSkip(isDay: true) => preferences.isOn(.notToday),
      // a program's while it is shown: a coach's under Your coach (#593)
      TrainingSkip() => preferences.programShown(program),
      null => false,
    };
    if (skip == null || !shown) {
      return Scaffold(appBar: AppBar(leading: leading));
    }

    final session = switch (skip.templateId) {
      final String id => Templates.watch(context).lookup(id)?.name,
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
                _ThatDay(key: ValueKey(skip.id), skip: skip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a day looked like to [_ThatDay]: the training before it, and the
/// health readings kept with it — null for a skip with no snapshot, whose
/// readings are the mirror's as it stands.
typedef _Day = ({SkipTraining training, Map<HealthMetric, double>? body});

/// What the day looked like when it was set aside (#312): the training before
/// it and what Health had for it, as the skip's snapshot kept them at that
/// moment (#445), so a workout deleted since, or the steps of the rest of the
/// day, change nothing here. The snapshot is this phone's alone: nothing of it
/// syncs, and the Health part goes when the mirror is forgotten
/// (`docs/2026-09-05.health-data.md`).
///
/// A skip without one — made before snapshots, or on another device — is
/// worked out from what this phone holds now, as every skip was before.
/// Weather joins it with #310.
class _ThatDay extends StatefulWidget {
  final TrainingSkip skip;

  const new({super.key, required this.skip});

  @override
  State<_ThatDay> createState() => _ThatDayState();
}

class _ThatDayState extends State<_ThatDay> {
  late Future<_Day> _day = _read();

  /// Whether the mirror held anything at the last look: once it is
  /// forgotten, the snapshot's readings went with it, and the day is read again.
  bool? _hadHealth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final has = Health.watch(context).hasData;
    if (_hadHealth == true && !has) _day = _read();
    _hadHealth = has;
  }

  Future<_Day> _read() async {
    final at = widget.skip.at;
    final stats = Stats.of(context);
    final taken = switch (widget.skip.id) {
      final String id => await SkipSnapshots.of(context).read(id),
      null => null,
    };
    // nothing of Health kept, whether Health had not caught up with the day
    // when the skip was recorded or the mirror was forgotten since: the
    // mirror answers, as for a skip with nothing kept at all
    if (taken case SkipSnapshot(:final training, :final body)) {
      return (training: training, body: body.isEmpty ? null : body);
    }
    final rows = await stats.getLensSets(at.subtract(skipTrainingReach), at);
    return (training: trainingOf(rows, at), body: null);
  }

  /// Calendar days from [from] to [to], both local: counted on the dates
  /// alone, so a day an hour short when the clocks change is still a day.
  static int _daysBetween(DateTime from, DateTime to) {
    return DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    // the mirror, for a skip with nothing kept, is watched in didChangeDependencies
    final preferences = Preferences.watch(context);
    final day = widget.skip.at.toLocal();

    return FutureBuilder<_Day>(
      future: _day,
      builder: (context, snapshot) {
        final SkipTraining(:lastWorkoutAt, :setsWeek, :recovering) =
            snapshot.data?.training ?? const SkipTraining(lastWorkoutAt: null, setsWeek: 0, recovering: {});
        // kept with the skip, or, for a skip with nothing kept, the mirror's
        final body = switch (snapshot.data) {
          (training: _, body: final Map<HealthMetric, double> body) => body,
          (training: _, body: null) => SkipSnapshots.of(context).bodyOn(widget.skip.at, takenAt: widget.skip.at),
          null => const <HealthMetric, double>{},
        };
        final readings = [
          for (final metric in skipBodyMetrics)
            if (body[metric] case final double value) (metric, metric.display(value, preferences, copy)),
        ];
        final groups = recovering.map(MuscleGroup.tryFromString).nonNulls;

        return Column(
          key: AppKeys.skipThatDay,
          crossAxisAlignment: .start,
          spacing: 4,
          children: [
            Text(copy.skipThatDay, style: textTheme.titleSmall),
            switch (lastWorkoutAt) {
              final DateTime last => Text(copy.skipDaysSince(_daysBetween(last.toLocal(), day))),
              null => Text(copy.skipNoWorkoutBefore),
            },
            Text(copy.skipSetsWeek(setsWeek)),
            if (groups.isNotEmpty) Text(copy.skipRecovering(groups.map((group) => group.label(copy)).join(', '))),
            if (readings.isNotEmpty) ...[
              const SizedBox(height: 12),
              // health values: hidden while a bug report captures the screen
              for (final (metric, (number, unit)) in readings)
                RedactedInCapture(
                  child: Text(
                    [
                      metric.label(copy),
                      number,
                      ?switch (unit) {
                        '' => null,
                        final String unit => unit,
                      },
                    ].join(' '),
                  ),
                ),
              Text(copy.skipFromHealth, style: muted),
            ],
          ],
        );
      },
    );
  }
}
