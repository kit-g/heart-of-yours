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

  /// The widest the label gets before it ends in an ellipsis, so the × stays in
  /// reach; as wide as it is, without one.
  final double maxLabelWidth;

  const new({
    super.key,
    required this.label,
    required this.onDeleted,
    this.avatar,
    this.maxLabelWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      deleteButtonTooltipMessage: L.of(context).removeFilter,
      labelPadding: .zero,
      avatar: avatar,
      label: Padding(
        padding: const .symmetric(horizontal: 4),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxLabelWidth),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: .ellipsis,
            semanticsLabel: label,
          ),
        ),
      ),
      visualDensity: const VisualDensity(vertical: -4),
      onDeleted: () {
        buzz();
        onDeleted();
      },
    );
  }
}
