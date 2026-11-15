import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What "last time" means under [child]: as of [before], for a past workout
/// that would otherwise be its own last time, and — with "Last time in this
/// template" on (#172) — the last run of [templateId] first.
///
/// Neither applying, [child] reads the app's own [PreviousExercises]. For
/// [someoneElse]'s workout, a coach's client's (#560), there is no last time:
/// this account never saw theirs, and no Previous column either:
/// [isSomeoneElses] says so to everything under it, a nested scope included.
class const PreviousScope({
  required final Widget child,
  final String? templateId,
  final DateTime? before,
  final bool someoneElse = false,
  super.key,
}) extends StatelessWidget {
  /// Whether what is under [context] is someone else's — a client's workout
  /// (#560), a session a coach writes (#591) — so this account's last time
  /// has no place beside it.
  static bool isSomeoneElses(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SomeoneElse>() != null;
  }

  @override
  Widget build(BuildContext context) {
    if (someoneElse) {
      return _SomeoneElse(
        child: ChangeNotifierProvider<PreviousExercises>(
          create: (context) => PreviousExercises.of(context).none(),
          child: child,
        ),
      );
    }
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

/// The mark [PreviousScope.isSomeoneElses] reads.
class _SomeoneElse extends InheritedWidget {
  const new({required super.child});

  @override
  bool updateShouldNotify(_SomeoneElse oldWidget) => false;
}
