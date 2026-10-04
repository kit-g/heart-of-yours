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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return FutureBuilder<List<AchievedRecord>>(
      future: _achieved,
      builder: (_, snapshot) {
        final block = switch (snapshot.data) {
          null || [] => const SizedBox(width: double.infinity),
          final achieved => _RecordBadges(achieved: achieved),
        };

        // Reduce Motion: it is simply there. Not a zero duration —
        // AnimatedSize re-dirties its own layout when it has none.
        if (reduceMotion) return block;

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
            child: block,
          ),
        );
      },
    );
  }
}

/// The records as badges, grouped by exercise, arriving one after another.
///
/// A record that beat nothing — the exercise's first time — is not news worth
/// a badge of its own: the first workout on a new account sets one on every
/// exercise it touches, and a badge each would be a wall. Those collapse into
/// a single count at the end.
class _RecordBadges extends StatefulWidget {
  final List<AchievedRecord> achieved;

  const new({required this.achieved});

  @override
  State<_RecordBadges> createState() => _RecordBadgesState();
}

class _RecordBadgesState extends State<_RecordBadges> with SingleTickerProviderStateMixin {
  /// Each badge's own entrance, and the gap before the next one starts.
  static const _entrance = 380;
  static const _step = 110;

  /// However many badges there are, the last one has landed by then — a
  /// stagger that outlasts the confetti reads as a loading screen.
  static const _longest = 1600;

  /// Records that beat an earlier value, by exercise. Keyed by the exercise
  /// itself: equality is the id, and the name is display copy.
  late final Map<Exercise, List<AchievedRecord>> _beaten = widget.achieved
      .where((each) => each.record['previous'] is Map)
      .fold({}, (acc, each) => acc..putIfAbsent(each.exercise, () => []).add(each));

  late final int _firsts = widget.achieved.where((each) => each.record['previous'] is! Map).length;

  /// Each beaten record's place in the stagger: reading order, top to
  /// bottom, with the firsts' summary after them all.
  late final Map<AchievedRecord, int> _order = {
    for (final (index, record) in _beaten.values.expand((each) => each).indexed) record: index,
  };

  late final int _count = _order.length + (_firsts > 0 ? 1 : 0);

  late final double _gap = switch (_count) {
    1 => 0,
    final count => min(_step, (_longest - _entrance) / (count - 1)).toDouble(),
  };

  late final AnimationController _stagger = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_entrance + _gap * (_count - 1)).round()),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: every badge is simply there
    switch (MediaQuery.disableAnimationsOf(context)) {
      case true:
        _stagger.value = 1;
      case false when _stagger.isDismissed:
        _stagger.forward();
      case false:
    }
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  /// The [index]th badge's slice of the stagger. A tween rather than a
  /// `CurvedAnimation`: this is asked on every build, and a `CurvedAnimation`
  /// hangs a listener on the controller that nothing here would dispose.
  Animation<double> _reveal(int index) {
    final total = _stagger.duration!.inMilliseconds;
    final start = index * _gap / total;
    return CurveTween(curve: Interval(start, min(1, start + _entrance / total))).animate(_stagger);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    final exercises = Exercises.watch(context);

    return Padding(
      padding: const .only(top: 32, left: 24, right: 24),
      child: ConstrainedBox(
        // a badge row stays a row of badges on a 1194pt window, not a strip
        // across it
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Column(
          spacing: 16,
          children: [
            Text(
              l.recordsAchievedHeading(widget.achieved.length),
              style: textTheme.titleMedium,
            ),
            for (final MapEntry(key: exercise, value: records) in _beaten.entries)
              Column(
                spacing: 8,
                children: [
                  Text(
                    exercise.name,
                    textAlign: .center,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  Wrap(
                    alignment: .center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final record in records) _recordBadge(context, exercise, record, l, prefs, exercises),
                    ],
                  ),
                ],
              ),
            if (_firsts > 0)
              _Badge(
                reveal: _reveal(_order.length),
                icon: Icons.flag_rounded,
                value: '$_firsts',
                detail: l.firstRecordsBadge(_firsts),
                semanticsLabel: l.firstRecordsLabel(_firsts),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recordBadge(
    BuildContext context,
    Exercise exercise,
    AchievedRecord record,
    L l,
    Preferences prefs,
    Exercises exercises,
  ) {
    final formats = RecordFormats(
      l: l,
      prefs: prefs,
      unit: exercises.unitFor(exercise.id),
      category: exercise.category,
    );
    final kind = recordKindLabel(context, record.kind);
    final value = formats.value(record.kind, record.record);
    final previous = formats.value(record.kind, record.record['previous'] as Map);

    return _Badge(
      reveal: _reveal(_order[record]!),
      icon: Icons.emoji_events_rounded,
      title: kind,
      value: value,
      detail: l.recordBadgeWas(previous),
      semanticsLabel: l.recordBadgeLabel(exercise.name, kind, value, previous),
    );
  }
}

/// One record: the accent medallion, what kind of record, the new value, and
/// what it beat. The firsts' summary has no kind: its count, then what it
/// counts. A single element to a screen reader.
class _Badge extends StatelessWidget {
  final Animation<double> reveal;
  final IconData icon;
  final String? title;
  final String value;
  final String? detail;
  final String semanticsLabel;

  const new({
    required this.reveal,
    required this.icon,
    this.title,
    required this.value,
    this.detail,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Semantics(
      container: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: reveal.drive(CurveTween(curve: const Interval(0, .6))),
        child: ScaleTransition(
          // the overshoot is the scale's alone: an opacity past 1 throws
          scale: reveal.drive(Tween<double>(begin: .8, end: 1).chain(CurveTween(curve: Curves.easeOutBack))),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: .all(color: colorScheme.outlineVariant),
              borderRadius: const .all(.circular(12)),
            ),
            child: Padding(
              padding: const .fromLTRB(10, 10, 16, 10),
              child: Row(
                mainAxisSize: .min,
                spacing: 10,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: colorScheme.tertiaryContainer, shape: .circle),
                    child: Padding(
                      padding: const .all(7),
                      child: Icon(icon, size: 18, color: colorScheme.onTertiaryContainer),
                    ),
                  ),
                  Flexible(
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: [
                        if (title case final String title)
                          Text(title, style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        Text(value, style: textTheme.titleMedium?.copyWith(fontWeight: .w700)),
                        if (detail case final String detail)
                          Text(detail, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
