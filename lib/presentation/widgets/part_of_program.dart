import 'package:heart/core/utils/shown_programs.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
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
    // a coach's program is shown under Your coach alone (#593)
    final program = switch (programId) {
      final String id => shownPrograms(context, listen: true).lookup(id),
      null => null,
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
