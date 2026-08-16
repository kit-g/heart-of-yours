import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/chart_dimension.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Picks an exercise, then the dimension to measure it by.
///
/// Shared rather than owned by the profile screen: charts and goals both start
/// from the same question, and the two vocabularies are the same strings.
///
/// [controller] and [focus] belong to the caller and outlive the dialog —
/// disposing them when this future completes pulls them out from under a field
/// that is still animating away.
Future<(Exercise, ChartPreferenceType)?> showExercisePicker(
  BuildContext context, {
  required TextEditingController controller,
  required FocusNode focus,
}) {
  final color = Theme.of(context).colorScheme.surfaceContainerLowest;

  return showDialog<(Exercise, ChartPreferenceType)?>(
    context: context,
    builder: (context) {
      final exercises = Exercises.watch(context);
      // a bare Card takes the whole screen; the picker still wants the height,
      // so only the width is bounded
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: dialogWidth),
          child: Card(
            child: ExercisePicker(
              appBar: SliverPersistentHeader(
                pinned: true,
                delegate: FixedHeightHeaderDelegate(
                  backgroundColor: color,
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      IconButton(
                        tooltip: L.of(context).close,
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -1),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  height: 40,
                  borderRadius: const .all(.circular(12)),
                ),
              ),
              exercises: exercises,
              backgroundColor: color,
              searchController: controller,
              focusNode: focus,
              onExerciseSelected: (exercise, details) async {
                final global = details?.globalPosition;
                if (global == null) return;
                final chartType = await showMenu<ChartPreferenceType>(
                  context: context,
                  position: global._position(),
                  items: ChartPreferenceType.chartsByExerciseCategory(exercise.category).map(
                    (option) {
                      return PopupMenuItem<ChartPreferenceType>(
                        value: option,
                        child: Text(option.label(context)),
                      );
                    },
                  ).toList(),
                );

                if (chartType != null && context.mounted) {
                  Navigator.of(context).pop((exercise, chartType));
                }
              },
            ),
          ),
        ),
      );
    },
  );
}

extension on Offset {
  RelativeRect _position() {
    return RelativeRect.fromLTRB(dx, dy, dx, dy);
  }
}
