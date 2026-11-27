import 'dart:math';

import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/muscle_figures.dart';
import 'package:heart/presentation/widgets/setting_picker.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';

// The muscles a custom exercise works, tagged on the body atlas (#176), so the
// muscle map and the pattern lens can count its sets the way they count the
// library's.

/// The muscles tagged in each role, by atlas id — the ids the library's own
/// tagging uses (`pectoralis_major_l`), so a custom tag reads exactly as a
/// library one does everywhere downstream.
typedef MuscleRoles = ({Set<String> primary, Set<String> secondary});

/// [tagging]'s muscle ids by role. Group-level tags (`chest`) are the
/// library's shorthand and a custom exercise never gets one here, so only ids
/// are read.
MuscleRoles rolesOf(MuscleTagging tagging) {
  return (
    primary: {...?tagging.primary.ids},
    secondary: {...?tagging.secondary?.ids},
  );
}

/// [roles] as the tagging an exercise carries; empty when nothing is tagged.
MuscleTagging taggingOf(MuscleRoles roles) {
  return MuscleTagging.fromJson({
    'primary': {'ids': roles.primary.toList()},
    if (roles.secondary.isNotEmpty) 'secondary': {'ids': roles.secondary.toList()},
  });
}

bool sameRoles(MuscleRoles a, MuscleRoles b) {
  return a.primary.length == b.primary.length &&
      a.secondary.length == b.secondary.length &&
      a.primary.containsAll(b.primary) &&
      a.secondary.containsAll(b.secondary);
}

enum _Role { primary, secondary }

// the atlas draws a muscle in segments and sides (`rectus_abdominis_2_l`); a
// tap means the muscle, so it tags every segment on both sides at once
final _segmentAndSide = RegExp(r'(_\d+)?(_[lr])?$');

String _family(String id) => id.replaceFirst(_segmentAndSide, '');

Set<String> _siblings(MuscleInfo muscle) {
  final family = _family(muscle.id);
  return {
    for (final each in MuscleCatalog.all)
      if (_family(each.id) == family) each.id,
  };
}

/// The body figures a custom exercise's muscles are picked on: a switch for
/// the role a tap gives, front and back, and a line per role naming what is
/// tagged — which is also what a screen reader hears, the figures being one
/// image to it.
class MusclePicker extends StatefulWidget {
  final ValueNotifier<MuscleRoles> roles;

  const new({super.key, required this.roles});

  @override
  State<MusclePicker> createState() => _MusclePickerState();
}

class _MusclePickerState extends State<MusclePicker> {
  final _role = ValueNotifier(_Role.primary);

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  void _onTap(MuscleInfo muscle) {
    final siblings = _siblings(muscle);
    final MuscleRoles(:primary, :secondary) = widget.roles.value;
    final (mine, other) = switch (_role.value) {
      .primary => (primary, secondary),
      .secondary => (secondary, primary),
    };
    // tapped again in the same role: untag; otherwise it moves to this role
    final tagged = mine.containsAll(siblings);
    final nextMine = tagged ? mine.difference(siblings) : mine.union(siblings);
    final nextOther = other.difference(siblings);
    widget.roles.value = switch (_role.value) {
      .primary => (primary: nextMine, secondary: nextOther),
      .secondary => (primary: nextOther, secondary: nextMine),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        // the switch drops under the title rather than squeezing it: two long
        // segments ("Вспомогательные") leave a phone-width title one word wide
        Wrap(
          alignment: .spaceBetween,
          crossAxisAlignment: .center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(l.exerciseMuscles, style: textTheme.titleMedium),
            ValueListenableBuilder<_Role>(
              valueListenable: _role,
              builder: (_, role, _) {
                return SettingSwitcher<_Role>(
                  key: AppKeys.musclePickerRole,
                  value: role,
                  onValueChanged: (picked) => _role.value = picked ?? role,
                  children: {
                    .primary: Text(l.exerciseMusclesPrimary),
                    .secondary: Text(l.exerciseMusclesSecondary),
                  },
                );
              },
            ),
          ],
        ),
        ValueListenableBuilder<MuscleRoles>(
          valueListenable: widget.roles,
          builder: (_, roles, _) {
            // the About page's two strengths of the one accent: tagging here
            // looks the way the exercise will look there
            final colors = {
              for (final muscle in MuscleCatalog.all)
                if (roles.primary.contains(muscle.id))
                  muscle: colorScheme.tertiary
                else if (roles.secondary.contains(muscle.id))
                  muscle: colorScheme.tertiary.withValues(alpha: .35),
            };
            final lines = [
              if (_groups(roles.primary, l) case String groups) l.exerciseMusclesPrimaryList(groups),
              if (_groups(roles.secondary, l) case String groups) l.exerciseMusclesSecondaryList(groups),
            ];

            return Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                LayoutBuilder(
                  builder: (_, constraints) {
                    return SizedBox(
                      // the muscle map's rule for the figures on their own
                      height: min(constraints.maxWidth * 4 / 5, 320),
                      child: MusclePanel(
                        help: l.exerciseMusclesHelp,
                        child: Semantics(
                          image: true,
                          label: l.exerciseMusclesPickerFigure,
                          excludeSemantics: true,
                          child: Row(
                            key: AppKeys.musclePickerFigures,
                            spacing: 8,
                            children: [
                              for (final view in [AtlasAsset.musclesFront, AtlasAsset.musclesBack])
                                Expanded(
                                  child: BodyAtlasView<MuscleInfo>(
                                    view: view,
                                    resolver: const MuscleResolver(),
                                    colorMapping: colors,
                                    onTapElement: _onTap,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                for (final line in lines)
                  Text(line, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            );
          },
        ),
      ],
    );
  }

  /// The atlas groups [ids] fall in, named, in the atlas's own order; null
  /// when nothing is tagged.
  String? _groups(Set<String> ids, L l) {
    if (ids.isEmpty) return null;
    final groups = {for (final id in ids) ?MuscleCatalog.tryById(id)?.group};
    return MuscleGroup.values.where(groups.contains).map((each) => each.label(l)).join(', ');
  }
}
