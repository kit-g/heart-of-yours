import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The one mark for "this belongs to a program": a template folder its
/// sessions live in, a workout started from one of them, an exercise it
/// trains. Tapped, it opens the program, by [onOpen] — which the place it
/// sits in decides: pushed within the Workout tab, gone to from another.
///
/// Absent while Programs is off, or when [programId] names no program this
/// device holds.
class PartOfProgram extends StatelessWidget {
  final String? programId;
  final void Function(Program program) onOpen;

  /// Smaller where it sits beside a line of text rather than in a header.
  final double size;

  const new({super.key, required this.programId, required this.onOpen, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final program = switch ((Preferences.watch(context).isOn(.programs), programId)) {
      (true, final String id) => Programs.watch(context).lookup(id),
      _ => null,
    };
    if (program == null) return const SizedBox.shrink();
    final ThemeData(:colorScheme) = Theme.of(context);

    return IconButton(
      key: AppKeys.partOfProgram(program.id),
      tooltip: L.of(context).programMarkOpen(program.name),
      onPressed: () => onOpen(program),
      icon: Icon(Icons.event_repeat_rounded, size: size, color: colorScheme.primary),
    );
  }
}
