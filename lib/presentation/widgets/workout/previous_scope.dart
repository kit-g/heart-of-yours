import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What "last time" means under [child]: as of [before], for a past workout
/// that would otherwise be its own last time, and — with "Last time in this
/// template" on (#172) — the last run of [templateId] first.
///
/// Neither applying, [child] reads the app's own [PreviousExercises].
class const PreviousScope({
  required final Widget child,
  final String? templateId,
  final DateTime? before,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final template = switch (Preferences.watch(context).isOn(.previousInTemplate)) {
      true => templateId,
      false => null,
    };
    if ((template, before) case (null, null)) return child;

    return ChangeNotifierProvider<PreviousExercises>(
      // a new scope for another template, or another moment
      key: ValueKey((template, before)),
      create: (context) {
        final previous = switch (before) {
          DateTime before => PreviousExercises.of(context).before(before),
          null => PreviousExercises.of(context),
        };
        return switch (template) {
          String template => previous.inTemplate(template),
          null => previous,
        }..init();
      },
      child: child,
    );
  }
}
