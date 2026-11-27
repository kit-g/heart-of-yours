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
        child: SizedBox(
          height: _height,
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
    );
  }
}

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
        border: here ? Border.all(color: ink) : null,
      ),
      child: ClipRRect(
        borderRadius: _corners,
        child: ColoredBox(
          color: colorScheme.outlineVariant,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: filled,
            heightFactor: 1,
            child: ColoredBox(color: ink),
          ),
        ),
      ),
    );
  }
}

/// This calendar week's workouts against the target, a ring each: ticked for
/// one done, empty for one still to do, and one more for each past the target.
/// Says itself in words on a long press and to a screen reader.
class WeekCount extends StatelessWidget {
  final int done;
  final int target;

  const new({super.key, required this.done, required this.target});

  static const _size = 18.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final words = L.of(context).programThisWeek(done, target);
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Tooltip(
        message: words,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            ...List.generate(
              done > target ? done : target,
              (index) => Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: .circle,
                  color: index < done ? colorScheme.primary : null,
                  border: Border.all(color: index < done ? colorScheme.primary : colorScheme.outline, width: 1.5),
                ),
                child: switch (index < done) {
                  true => Icon(Icons.check_rounded, size: 12, color: colorScheme.onPrimary),
                  false => null,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
