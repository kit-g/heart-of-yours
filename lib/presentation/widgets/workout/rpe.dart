part of 'workout_detail.dart';

/// The ratings on offer, in the half steps the server takes (#234). Below 6
/// the guess stops being reliable, so the scale starts there. Three rows of
/// three, the way a number pad reads.
const _rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

/// What the set-number popup returns: a type for the set, or a rating.
sealed class _SetChoice {
  const new();
}

final class _TypeChoice extends _SetChoice {
  final SetType type;

  const new(this.type);
}

final class _RpeChoice extends _SetChoice {
  final double rpe;

  const new(this.rpe);
}

/// The set's rating, taken away.
final class _RpeCleared extends _SetChoice {
  const new();
}

/// RPE in the set-number popup (#234): a heading with the set's rating and a
/// help button, and the ratings under it. Only while the feature is on and the
/// screen rates sets; otherwise the popup is the three types alone.
///
/// Its own entry rather than a [PopupMenuItem], because it is not one choice
/// but nine: each rating closes the popup with itself.
class _RpeEntry extends PopupMenuEntry<_SetChoice> {
  final ExerciseSet set;

  /// Whether the scale is unfolded under the heading; shared with the popup's
  /// owner, which folds it again when the popup closes.
  final ValueNotifier<bool> explained;

  const new({required this.set, required this.explained});

  /// What the popup positions itself by before it lays the entry out: the
  /// heading and three rows of ratings.
  @override
  double get height => 200;

  @override
  bool represents(_SetChoice? value) => false;

  @override
  State<_RpeEntry> createState() => _RpeEntryState();
}

class _RpeEntryState extends State<_RpeEntry> {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final l = L.of(context);
    final ExerciseSet(:rpe) = widget.set;

    return Container(
      width: _setTypeMenuWideWidth,
      // the hairline that sets the ratings apart from the types above
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: .5)),
      ),
      padding: const .fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            spacing: 12,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '@',
                  textAlign: .center,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: .w700),
                ),
              ),
              Expanded(
                child: Text(
                  switch (rpe) {
                    double rpe => l.rpeValue(_rpeText(context, rpe)),
                    null => l.rpe,
                  },
                  style: textTheme.titleSmall,
                ),
              ),
              // only while there is a rating to take away
              if (rpe != null)
                IconButton(
                  key: WorkoutDetailKeys.clearRpe,
                  tooltip: l.clearRpe,
                  visualDensity: .compact,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(const _RpeCleared()),
                ),
              IconButton(
                tooltip: l.aboutRpe,
                visualDensity: .compact,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
                ),
                icon: const Icon(Icons.question_mark_rounded, size: 18),
                onPressed: () => widget.explained.value = !widget.explained.value,
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.explained,
            builder: (context, open, _) {
              final style = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
              return AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: .topCenter,
                child: switch (open) {
                  true => Padding(
                    padding: const .only(top: 2, bottom: 8),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Padding(
                          padding: const .only(bottom: 4),
                          child: Text(l.rpeHint, style: style),
                        ),
                        for (final line in [l.rpeScale10, l.rpeScale9, l.rpeScale8, l.rpeScale7, l.rpeScale6])
                          Text(line, style: style),
                      ],
                    ),
                  ),
                  false => const SizedBox(width: double.infinity),
                },
              );
            },
          ),
          for (final row in [_rpeValues.sublist(0, 3), _rpeValues.sublist(3, 6), _rpeValues.sublist(6)])
            Padding(
              padding: const .only(top: 4),
              child: Row(
                spacing: 4,
                children: [
                  for (final value in row)
                    Expanded(
                      child: _RpeValue(
                        value: value,
                        label: _rpeText(context, value),
                        selected: rpe == value,
                        onPressed: () => Navigator.of(context).pop(_RpeChoice(value)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class const _RpeValue({
  required final double value,
  required final String label,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Semantics(
      selected: selected,
      child: PrimaryButton.shrunk(
        key: WorkoutDetailKeys.rpeValue(value),
        // 44 tall: Apple's floor for a tap target, and no roomier
        margin: const .symmetric(vertical: 12),
        // the accent fill is the rating the set has; the rest sit quiet
        backgroundColor: switch (selected) {
          true => null,
          false => colorScheme.surfaceContainerHighest,
        },
        onPressed: onPressed,
        child: Center(
          child: Text(
            label,
            // the text style names a colour of its own, so the accent's ink
            // has to be asked for
            style: textTheme.titleSmall?.copyWith(
              color: switch (selected) {
                true => colorScheme.onTertiaryContainer,
                false => null,
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// An RPE as the user's language writes it: "8", "8.5", or "8,5".
String _rpeText(BuildContext context, double rpe) {
  return NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(rpe);
}
