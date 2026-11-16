import 'package:heart/core/utils/misc.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

/// One filter that is on, and its × to take it off: the exercise picker's
/// filters and History's muscle groups (#610) are the same chip, so the two
/// screens filter alike.
class RemovableChip extends StatelessWidget with HasHaptic<RemovableChip> {
  final String label;
  final VoidCallback onDeleted;

  /// Before the label: a muscle family's dot, on History's chips (#617).
  final Widget? avatar;

  const new({super.key, required this.label, required this.onDeleted, this.avatar});

  @override
  Widget build(BuildContext context) {
    return Chip(
      deleteButtonTooltipMessage: L.of(context).removeFilter,
      labelPadding: .zero,
      avatar: avatar,
      label: Padding(
        padding: const .symmetric(horizontal: 4),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      visualDensity: const VisualDensity(vertical: -4),
      onDeleted: () {
        buzz();
        onDeleted();
      },
    );
  }
}
