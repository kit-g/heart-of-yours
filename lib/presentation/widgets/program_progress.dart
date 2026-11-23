import 'package:heart/core/utils/visual.dart' show lineWidth;
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

/// A program's weeks as a bar of them: those behind filled, the one under way
/// filled as far as its sessions are done, those ahead faint. Says itself in
/// words on a long press and to a screen reader.
class ProgramWeeksBar extends StatelessWidget {
  final int week;
  final int weeks;

  /// How far into [week] its sessions are, 0 to 1.
  final double done;

  /// A program on hold keeps its place, in a quiet colour.
  final bool paused;

  const new({super.key, required this.week, required this.weeks, required this.done, this.paused = false});

  static const _height = 6.0;
  static const _gap = 3.0;

  /// Around the bar, so a long press needn't find its six points.
  static const _reach = 5.0;

  /// Narrower than this, weeks stop being told apart: they are one bar.
  static const _narrowest = 6.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final ink = paused ? colorScheme.outline : colorScheme.primary;
    final words = L.of(context).programWeekOf(week, weeks);
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Tooltip(
        message: words,
        child: Container(
          // as wide as the card, whatever the column offers
          width: double.infinity,
          color: Colors.transparent,
          padding: const .symmetric(vertical: _reach),
          child: SizedBox(
            height: _height * _growth(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segment = (constraints.maxWidth - _gap * (weeks - 1)) / weeks;
                return switch (segment >= _narrowest) {
                  true => Row(
                    spacing: _gap,
                    children: [
                      ...List.generate(
                        weeks,
                        (index) => Expanded(
                          child: _Segment(
                            filled: switch (index + 1 - week) {
                              < 0 => 1,
                              0 => done.clamp(0, 1).toDouble(),
                              _ => 0,
                            },
                            ink: ink,
                            here: index + 1 == week,
                          ),
                        ),
                      ),
                    ],
                  ),
                  false => _Segment(filled: ((week - 1 + done) / weeks).clamp(0, 1).toDouble(), ink: ink),
                };
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// How much larger than at the standard text size these are drawn: with the
/// words beside them, up to a point.
double _growth(BuildContext context) => (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.6).toDouble();

class _Segment extends StatelessWidget {
  final double filled;
  final Color ink;

  /// The week under way, outlined, so it is found while nothing of it is done.
  final bool here;

  const new({required this.filled, required this.ink, this.here = false});

  static const _corners = BorderRadius.all(.circular(3));

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    return DecoratedBox(
      position: .foreground,
      decoration: BoxDecoration(
        borderRadius: _corners,
        border: .all(color: here || filled == 1 ? ink : colorScheme.outline),
      ),
      child: ClipRRect(
        borderRadius: _corners,
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: filled,
          heightFactor: 1,
          child: ColoredBox(color: ink),
        ),
      ),
    );
  }
}

/// This calendar week's workouts against the target, a ring each: ticked for
/// one done, empty for one still to do, and one more for each past the target,
/// then the words that say which week.
/// Says itself in words on a long press and to a screen reader.
class WeekCount extends StatelessWidget {
  final int done;
  final int target;

  const new({super.key, required this.done, required this.target});

  static const _size = 18.0;
  static const _between = 4.0;
  static const _beforeWords = 8.0;

  /// More than these are counted in words: a wall of rings says less.
  static const _most = 7;

  bool get _ringed => done <= _most && target <= _most;

  int get _rings => done > target ? done : target;

  /// How wide this is on one line.
  double widthIn(BuildContext context) {
    final l = L.of(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    return switch (_ringed) {
      true =>
        _rings * _size * _growth(context) +
            (_rings - 1) * _between +
            _beforeWords +
            lineWidth(context, l.programThisWeekLabel, style: style),
      false => lineWidth(context, l.programThisWeek(done, target), style: style),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final words = L.of(context).programThisWeek(done, target);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    if (!_ringed) return Text(words, style: muted);
    final size = _size * _growth(context);
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Tooltip(
        message: words,
        // the words go below the rings where there isn't room beside them
        child: Wrap(
          spacing: _beforeWords,
          runSpacing: 4,
          crossAxisAlignment: .center,
          children: [
            Wrap(
              spacing: _between,
              runSpacing: 4,
              children: List.generate(
                _rings,
                (index) => Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: .circle,
                    color: index < done ? colorScheme.primary : null,
                    border: .all(color: index < done ? colorScheme.primary : colorScheme.outline, width: 1.5),
                  ),
                  child: switch (index < done) {
                    true => Icon(Icons.check_rounded, size: size * 2 / 3, color: colorScheme.onPrimary),
                    false => null,
                  },
                ),
              ),
            ),
            Text(L.of(context).programThisWeekLabel, style: muted),
          ],
        ),
      ),
    );
  }
}
