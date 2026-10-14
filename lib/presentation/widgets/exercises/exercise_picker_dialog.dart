import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/chart_dimension.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

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
  return showDialog<(Exercise, ChartPreferenceType)?>(
    context: context,
    builder: (context) {
      return _PickerCard(
        controller: controller,
        focus: focus,
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
      );
    },
  );
}

/// Picks one exercise, and that is the answer.
///
/// [except] is shown highlighted, as the one the question is about, and a tap
/// on it is not an answer. An exercise [refuses] gives a reason for stays
/// listed but greyed, and a tap on it shows the reason. The search field's controller and focus belong to
/// the dialog, so they go when its route does, never under a field still
/// animating away.
Future<Exercise?> showSingleExercisePicker(
  BuildContext context, {
  ExerciseId? except,
  String? Function(Exercise)? refuses,
}) {
  return showDialog<Exercise?>(
    context: context,
    builder: (_) => _SingleExercisePicker(except: except, refuses: refuses),
  );
}

class _SingleExercisePicker extends StatefulWidget {
  final ExerciseId? except;
  final String? Function(Exercise)? refuses;

  const new({this.except, this.refuses});

  @override
  State<_SingleExercisePicker> createState() => _SingleExercisePickerState();
}

class _SingleExercisePickerState extends State<_SingleExercisePicker> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PickerCard(
      controller: _controller,
      focus: _focus,
      highlighted: widget.except,
      refuses: widget.refuses,
      onExerciseSelected: (exercise, _) {
        if (exercise.id != widget.except) Navigator.of(context).pop(exercise);
      },
    );
  }
}

/// The picker in a card no wider than a dialog, with a close button above it.
class _PickerCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final void Function(Exercise, TapDownDetails?) onExerciseSelected;
  final ExerciseId? highlighted;
  final String? Function(Exercise)? refuses;

  const new({
    required this.controller,
    required this.focus,
    required this.onExerciseSelected,
    this.highlighted,
    this.refuses,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerLowest;
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
            highlightedName: highlighted,
            refuses: refuses,
            onExerciseSelected: onExerciseSelected,
          ),
        ),
      ),
    );
  }
}

extension on Offset {
  RelativeRect _position() {
    return RelativeRect.fromLTRB(dx, dy, dx, dy);
  }
}
