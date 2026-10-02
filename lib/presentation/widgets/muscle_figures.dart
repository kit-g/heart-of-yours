import 'dart:async';
import 'dart:math';

import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:heart/core/utils/muscle_volume.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// The muscle map's body figures (#136), on the profile for a window of days
// and on a single finished workout (#223).

/// One finished workout's figures, under a heading: what it worked, shaded by
/// its own busiest group. Nothing at all when the muscle map's per-workout
/// part is off, or when no set in it could be placed — an untinted body would
/// say "you trained nothing".
class const WorkoutMuscleMap({
  super.key,
  required final Workout workout,

  /// Around the map when there is one, so a map that is not there leaves no
  /// gap either.
  final EdgeInsetsGeometry padding = .zero,
}) extends StatelessWidget {
  /// Whether [workout] has anything to draw, for a caller deciding whether to
  /// offer the map at all.
  static bool shows(BuildContext context, Workout workout) {
    return Preferences.of(context).isOptionOn(.muscleMapWorkout) && _volume(context, workout).sets.isNotEmpty;
  }

  static MuscleVolume _volume(BuildContext context, Workout workout) {
    return muscleVolume(workoutMuscleSets(workout, lookup: Exercises.of(context).lookup));
  }

  @override
  Widget build(BuildContext context) {
    if (!Preferences.watch(context).isOptionOn(.muscleMapWorkout)) return const SizedBox.shrink();
    final (:sets, unmapped: _) = _volume(context, workout);
    if (sets.isEmpty) return const SizedBox.shrink();

    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final most = sets.values.fold(0.0, max);

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          key: AppKeys.workoutMuscleMap,
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              Text(l.musclesWorked, style: textTheme.titleMedium),
              LayoutBuilder(
                builder: (_, constraints) {
                  return SizedBox(
                    // the profile's rule for the figures on their own
                    height: min(constraints.maxWidth * 4 / 5, 320),
                    child: MuscleFigures(
                      help: l.workoutMuscleMapHelp,
                      sets: sets,
                      colors: {
                        for (final muscle in MuscleCatalog.all)
                          if (sets[muscle.group] case double count when count > 0)
                            muscle: muscleShade(colorScheme, count, most),
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group's shade on the map, by its share of the busiest group, with a floor
/// so one set still shows. The accent the exercise page uses for "primary", at
/// strengths.
Color muscleShade(ColorScheme colorScheme, double count, double most) {
  return colorScheme.tertiary.withValues(alpha: .2 + .8 * count / most);
}

/// Front and back, shaded. One image to assistive tech: the numbers are in
/// words elsewhere — the profile's list, or a tap here.
///
/// Tapping a muscle names its group and that group's sets, in a label over the
/// figures that fades after a few seconds — a shortcut for anyone reading the
/// body rather than the list, not the only way to the number.
class MuscleFigures extends StatefulWidget {
  final Map<MuscleInfo, Color> colors;

  /// The sets per group on show — what a tap reports.
  final Map<MuscleGroup, double> sets;

  /// What the figures show, behind the panel's "?".
  final String help;

  const new({super.key, required this.colors, required this.sets, required this.help});

  @override
  State<MuscleFigures> createState() => _MuscleFiguresState();
}

class _MuscleFiguresState extends State<MuscleFigures> {
  /// The group last tapped, while its label is up.
  final _tapped = ValueNotifier<MuscleGroup?>(null);
  Timer? _fade;

  static const _shown = Duration(seconds: 3);

  @override
  void dispose() {
    _fade?.cancel();
    _tapped.dispose();
    super.dispose();
  }

  void _onTap(MuscleInfo muscle) {
    _fade?.cancel();
    _tapped.value = muscle.group;
    _fade = Timer(_shown, () => _tapped.value = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return MusclePanel(
      help: widget.help,
      child: Stack(
        children: [
          // one image to assistive tech; the help beside it stays its own control
          Semantics(
            image: true,
            label: l.muscleMapFigure,
            excludeSemantics: true,
            child: Row(
              spacing: 8,
              children: [
                for (final view in [AtlasAsset.musclesFront, AtlasAsset.musclesBack])
                  Expanded(
                    child: BodyAtlasView<MuscleInfo>(
                      view: view,
                      resolver: const MuscleResolver(),
                      colorMapping: widget.colors,
                      onTapElement: _onTap,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<MuscleGroup?>(
                valueListenable: _tapped,
                builder: (_, group, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: switch (group) {
                      MuscleGroup group => Center(
                        key: ValueKey(group),
                        child: Container(
                          key: AppKeys.muscleMapFigureTip,
                          padding: const .symmetric(horizontal: 10, vertical: 6),
                          // the tooltip's own look: this is one, pinned
                          decoration: BoxDecoration(
                            color: colorScheme.inverseSurface,
                            borderRadius: const .all(.circular(6)),
                          ),
                          child: Text(
                            setsOfGroup(l, group, widget.sets[group] ?? 0),
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
                          ),
                        ),
                      ),
                      null => const SizedBox.shrink(),
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet inset the muscle map draws its content on.
class const MusclePanel({
  super.key,
  required final Widget child,

  /// What the box shows, behind a "?" in its top-right corner.
  final String? help,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(12)),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      padding: const .all(12),
      child: child,
    );

    return switch (help) {
      String help => Stack(
        children: [
          box,
          Positioned(top: 0, right: 0, child: PanelHelp(message: help)),
        ],
      ),
      null => box,
    };
  }
}

/// A "?" that explains the box it sits in. Tap, not long-press: a help mark
/// nobody knows to hold down explains nothing. The whole 48pt square answers
/// the tap, not only the 18pt glyph.
class const PanelHelp({
  super.key,
  required final String message,
}) extends StatelessWidget {
  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    return _Tip(
      message: message,
      showDuration: const Duration(seconds: 10),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: Colors.transparent,
          child: Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The map's tooltips, all of them opened by a tap: opaque and inset from the
/// screen's edges. Flutter's default is a translucent grey band running edge
/// to edge, which over the list below it left both unreadable.
class const _Tip({
  required final String message,
  required final Widget child,
  final Duration? showDuration,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Tooltip(
      message: message,
      triggerMode: .tap,
      showDuration: showDuration,
      margin: const .symmetric(horizontal: 16),
      padding: const .symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: readableWidth),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: const .all(.circular(8)),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
      child: child,
    );
  }
}

extension MuscleGroupCopy on MuscleGroup {
  String label(L l) {
    return switch (this) {
      .legs => l.targetLegs,
      .adductors => l.muscleGroupAdductors,
      .hamstrings => l.muscleGroupHamstrings,
      .glutes => l.muscleGroupGlutes,
      .arms => l.targetArms,
      .neck => l.muscleGroupNeck,
      .back => l.targetBack,
      .core => l.targetCore,
      .shoulders => l.targetShoulders,
      .chest => l.targetChest,
    };
  }
}

/// "Chest: 4 sets" — a group and its count, halves and all. Whole counts take
/// the plural forms; a half cannot, so it has its own phrasing.
String setsOfGroup(L l, MuscleGroup group, double sets) {
  return switch (sets % 1 == 0) {
    true => l.muscleMapMuscleSets(group.label(l), sets.toInt()),
    false => l.muscleMapMuscleSetsFractional(group.label(l), NumberFormat('#,##0.#', l.localeName).format(sets)),
  };
}
