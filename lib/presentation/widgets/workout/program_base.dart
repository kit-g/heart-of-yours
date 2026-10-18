part of 'workout_detail.dart';

/// Whether [rule] grows a weight from a base the user can set: a training
/// max (a share-of-max rule) or a working weight. Ladders climb exercises and
/// [Longer] grows a length, so neither has one to set here.
bool hasWeightBase(GrowthRule? rule) {
  return switch (rule) {
    AddWeight() || RangeThenWeight() || ShareOfMax() || Stages() => true,
    _ => false,
  };
}

/// The base [rule] holds for [exercise] in words: "Training max: 60 kg" for a
/// share-of-max rule, "Working weight: 60 kg" otherwise.
String baseLine(BuildContext context, Exercise exercise, GrowthRule? rule, num value) {
  final copy = L.of(context);
  final weight = _BaseUnit.of(context, exercise).format(value);
  return switch (rule) {
    ShareOfMax() => copy.programBaseTrainingMax(weight),
    _ => copy.programBaseWorking(weight),
  };
}

/// Asks for [exercise]'s base under [rule], in the unit its weights show in,
/// prefilled with [value]. Returns it stored (kilograms), or null when
/// cancelled. [seeding] asks where a newly placed exercise starts: [value] is
/// the suggestion from the user's own sets, or null with none to go on, and
/// cancelling it is "leave it to the first session".
Future<num?> showProgramBaseEditor(
  BuildContext context, {
  required Exercise exercise,
  required GrowthRule? rule,
  required num? value,
  bool seeding = false,
}) {
  return showDialog<num>(
    context: context,
    builder: (_) => _BaseEditor(exercise: exercise, rule: rule, value: value, seeding: seeding),
  );
}

/// A weight in the unit [exercise] shows weights in: its own, else the
/// user's.
class _BaseUnit {
  final MeasurementUnit unit;
  final String label;

  const new _(this.unit, this.label);

  factory of(BuildContext context, Exercise exercise) {
    final copy = L.of(context);
    final unit = Exercises.of(context).unitFor(exercise.id) ?? Preferences.of(context).weightUnit;
    return _BaseUnit._(unit, switch (unit) {
      .imperial => copy.lbs,
      .metric => copy.kg,
    });
  }

  /// [kilograms] as shown: one decimal at most.
  num shown(num kilograms) {
    final value = switch (unit) {
      .imperial => kilograms.asPounds,
      .metric => kilograms.toDouble(),
    };
    return (value * 10).round() / 10;
  }

  num stored(num shown) {
    return switch (unit) {
      .imperial => shown.toDouble().asKilograms,
      .metric => shown,
    };
  }

  String format(num kilograms) => '${NumberFormat('#,##0.#').format(shown(kilograms))} $label';
}

class _BaseEditor extends StatefulWidget {
  final Exercise exercise;
  final GrowthRule? rule;
  final num? value;
  final bool seeding;

  const new({required this.exercise, required this.rule, required this.value, required this.seeding});

  @override
  State<_BaseEditor> createState() => _BaseEditorState();
}

class _BaseEditorState extends State<_BaseEditor> {
  late final _unit = _BaseUnit.of(context, widget.exercise);
  late final _field = TextEditingController(
    text: switch (widget.value) {
      final num value => NumberFormat('0.#').format(_unit.shown(value)),
      null => '',
    },
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// The number typed, in the shown unit; null unless it is a weight.
  num? _parsed(String text) {
    return switch (num.tryParse(text.trim().replaceAll(',', '.'))) {
      final num value when value > 0 && value < 2000 => value,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final name = widget.exercise.name;
    final kind = switch (widget.rule) {
      ShareOfMax() => copy.programTrainingMax,
      _ => copy.programWorkingWeight,
    };
    final note = switch ((widget.seeding, widget.value)) {
      (true, num()) => copy.programBaseSeedFromHistory,
      (true, null) => copy.programBaseSeedNoHistory,
      (false, _) => null,
    };

    return AlertDialog(
      key: WorkoutDetailKeys.programBaseEditor,
      title: Text(switch (widget.seeding) {
        true => copy.programBaseSeedTitle(name),
        false => copy.programBaseChange(name),
      }),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: dialogWidth),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            if (note != null) Text(note, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            TextField(
              key: WorkoutDetailKeys.programBaseField,
              controller: _field,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: kind, suffixText: _unit.label),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(switch (widget.seeding) {
            true => copy.skip,
            false => copy.cancel,
          }),
        ),
        ValueListenableBuilder(
          valueListenable: _field,
          builder: (context, text, _) {
            return PrimaryButton.shrunk(
              key: WorkoutDetailKeys.programBaseSave,
              onPressed: switch (_parsed(text.text)) {
                final num value => () => Navigator.of(context).pop(_unit.stored(value)),
                null => null,
              },
              child: Text(copy.save),
            );
          },
        ),
      ],
    );
  }
}
