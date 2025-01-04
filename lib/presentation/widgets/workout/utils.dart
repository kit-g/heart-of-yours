part of 'active_workout.dart';

const _fixedColumnWidth = 32.0;
const _fixedButtonHeight = 24.0;
const _emptyValue = '-';

final _inputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?')),
  LengthLimitingTextInputFormatter(5), // todo change to five digits, e.g. 123.45
  FilteringTextInputFormatter.singleLineFormatter,
];

void _selectAllText(TextEditingController controller) {
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.value.text.length,
  );
}

enum _ExerciseOption {
  addNote,
  replace,
  weightUnit,
  autoRestTimer,
  remove;
}
