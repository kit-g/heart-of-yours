part of 'exercises.dart';

/// What [exercise] is harder on among the things the user goes easy on
/// (#396): empty unless Programs is on, the map is published and something
/// listed is harder on it. A mark is never a block.
List<GoEasyEntry> goEasyMarks(BuildContext context, Exercise exercise) {
  if (!Preferences.watch(context).isOn(.programs)) return const [];
  return GoEasy.watch(context).harderOn(exercise);
}

/// The listed things' names, joined: "Knee, Jumping and impact".
String _names(Iterable<GoEasyEntry> entries) {
  final tag = languageTag();
  return entries.map((entry) => entry.name.of(tag)).join(', ');
}

/// The neutral mark on an exercise harder on something the user goes easy
/// on: a leaf and what it is harder on, in the muted ink. With [exercise]
/// and [candidates] it opens the kinder swaps; without, it only says so — a
/// picker row has a tap of its own.
class GoEasyMarker extends StatelessWidget {
  final List<GoEasyEntry> marks;
  final Exercise? exercise;
  final Iterable<Exercise> candidates;

  const new({super.key, required this.marks, this.exercise, this.candidates = const []});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final color = colorScheme.onSurfaceVariant;
    final names = _names(marks);
    final mark = Row(
      mainAxisSize: .min,
      spacing: 4,
      children: [
        Icon(Icons.spa_outlined, size: 14, color: color),
        Flexible(
          child: Text(
            names,
            maxLines: 1,
            overflow: .ellipsis,
            style: textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );

    return switch (exercise) {
      // its own node: a tap target of its own inside a card that reads as one
      final Exercise exercise => Semantics(
        container: true,
        button: true,
        label: copy.goEasyHarderOn(names),
        excludeSemantics: true,
        child: InkWell(
          borderRadius: const .all(.circular(6)),
          onTap: () => showKinderSwaps(context, [exercise], candidates: candidates),
          child: Padding(padding: const .symmetric(vertical: 4), child: mark),
        ),
      ),
      null => Semantics(label: copy.goEasyHarderOn(names), excludeSemantics: true, child: mark),
    };
  }
}

/// Kinder swaps for each of [exercises], under what the map calls them
/// ("Easier on your knee"). Suggestions only: what a session holds changes in
/// its template, so nothing here changes anything.
Future<void> showKinderSwaps(BuildContext context, List<Exercise> exercises, {required Iterable<Exercise> candidates}) {
  final easy = GoEasy.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) => _KinderSwaps(easy: easy, exercises: exercises, candidates: candidates),
  );
}

class _KinderSwaps extends StatelessWidget {
  /// Passed in: the sheet is a route of its own.
  final GoEasy easy;
  final List<Exercise> exercises;
  final Iterable<Exercise> candidates;

  const new({required this.easy, required this.exercises, required this.candidates});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final tag = languageTag();
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: ListView(
          shrinkWrap: true,
          padding: const .fromLTRB(16, 24, 16, 16),
          children: [
            for (final exercise in exercises) ...[
              Text(exercise.name, style: textTheme.titleMedium),
              Text(easy.harderOn(exercise).map((entry) => entry.easierOn.of(tag)).join(' · '), style: muted),
              const SizedBox(height: 8),
              ...switch (easy.kinderSwaps(exercise, candidates)) {
                [] => [Text(copy.goEasyNoSwaps, style: textTheme.bodyMedium)],
                final swaps => [
                  for (final swap in swaps)
                    ListTile(
                      contentPadding: .zero,
                      dense: true,
                      leading: ExerciseBadge(exercise: swap),
                      title: Text(swap.name),
                      subtitle: Text('${swap.target.label(copy)} - ${swap.category.label(copy)}'),
                    ),
                ],
              },
              const SizedBox(height: 16),
            ],
            Text(copy.goEasySwapsNote, style: muted),
          ],
        ),
      ),
    );
  }
}

/// The list itself: every area and movement of the map as a chip, on as the
/// user goes easy on it. A chip applies at once, as the movement filters do,
/// and the list stays on this phone.
Future<void> showGoEasySheet(BuildContext context) {
  final easy = GoEasy.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) => _GoEasySheet(easy: easy),
  );
}

class _GoEasySheet extends StatelessWidget with HasHaptic<_GoEasySheet> {
  final GoEasy easy;

  const new({required this.easy});

  @override
  Widget build(BuildContext context) {
    final tag = languageTag();
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return ListenableBuilder(
      listenable: easy,
      builder: (context, _) {
        final content = easy.content;
        if (content == null) return const SizedBox.shrink();
        final keys = easy.keys;

        Widget chips(List<GoEasyEntry> entries) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries)
                FilterChip(
                  key: AppKeys.goEasy(entry.key),
                  label: Text(entry.name.of(tag), style: textTheme.bodyMedium),
                  visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  selected: keys.contains(entry.key),
                  onSelected: (on) {
                    buzz();
                    easy.set({...keys.where((key) => key != entry.key), if (on) entry.key});
                  },
                ),
            ],
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const .fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 16,
              children: [
                if (content.title case final ContentText title) Text(title.of(tag), style: textTheme.titleMedium),
                if (content.explainer case final ContentText explainer) Text(explainer.of(tag), style: muted),
                chips(content.areas),
                chips(content.movements),
                if (content.footer case final ContentText footer) Text(footer.of(tag), style: muted),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A row that says what the user goes easy on and opens the list: in program
/// setup and on a library program's page. Absent while Programs is off or
/// the map isn't published.
class GoEasyRow extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final easy = GoEasy.watch(context);
    final title = easy.content?.title;
    if (!Preferences.watch(context).isOn(.programs) || title == null) return const SizedBox.shrink();
    final listed = easy.listed;

    return ListTile(
      key: AppKeys.goEasyRow,
      // the ink inset from the row's content and rounded, as Settings'
      // option rows: flush, it was a hard-edged block cut at the icon
      contentPadding: const .symmetric(horizontal: 8),
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
      leading: const Icon(Icons.spa_outlined),
      title: Text(title.of(languageTag())),
      subtitle: Text(switch (listed) {
        [] => copy.goEasyNothing,
        _ => _names(listed),
      }),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showGoEasySheet(context),
    );
  }
}

/// What one program goes easy on (#355), on its page: an area or a movement
/// of the map, which every replacement suggested inside the program leaves
/// out. The program's own, chosen here, and never read from the user's list —
/// that list stays on this phone, and this choice syncs with the program.
/// Absent while the map isn't published: there is nothing to name it by.
class ProgramConstraintRow extends StatelessWidget {
  final Program program;

  const new({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final easy = GoEasy.watch(context);
    if (!easy.available) return const SizedBox.shrink();
    final entry = easy.entryFor(program.constraint);

    return ListTile(
      key: AppKeys.programConstraint,
      // the ink inset from the row's content and rounded, as Settings'
      // option rows: flush, it was a hard-edged block cut at the icon
      contentPadding: const .symmetric(horizontal: 8),
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
      leading: const Icon(Icons.filter_alt_outlined),
      title: Text(copy.programConstraint),
      subtitle: Text(switch (entry) {
        final GoEasyEntry entry => entry.name.of(languageTag()),
        null => copy.programConstraintNone,
      }),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showProgramConstraintSheet(context, program.id!),
    );
  }
}

Future<void> _showProgramConstraintSheet(BuildContext context, String programId) {
  final easy = GoEasy.of(context);
  final programs = Programs.of(context);
  final analytics = Analytics.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (context) {
      return _ProgramConstraintSheet(easy: easy, programs: programs, analytics: analytics, programId: programId);
    },
  );
}

/// One choice among the map's areas and movements, or none. A chip applies
/// at once, as the user's own list does.
class _ProgramConstraintSheet extends StatelessWidget with HasHaptic<_ProgramConstraintSheet> {
  /// Passed in: the sheet is a route of its own.
  final GoEasy easy;
  final Programs programs;
  final Analytics analytics;
  final String programId;

  const new({required this.easy, required this.programs, required this.analytics, required this.programId});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final tag = languageTag();
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return ListenableBuilder(
      listenable: Listenable.merge([easy, programs]),
      builder: (context, _) {
        final program = programs.lookup(programId);
        final content = easy.content;
        if (program == null || content == null) return const SizedBox.shrink();
        final chosen = easy.entryFor(program.constraint)?.key;

        Future<void> choose(String? key) async {
          if (key == chosen) return;
          buzz();
          await programs.update(switch (key) {
            final String key => program.copyWith(constraint: key),
            null => program.without({.constraint}),
          });
          analytics.programConstraint(set: key != null);
        }

        Widget chip(String? key, String label) {
          return ChoiceChip(
            key: AppKeys.programConstraintChoice(key),
            label: Text(label, style: textTheme.bodyMedium),
            visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
            backgroundColor: colorScheme.surfaceContainerHigh,
            selected: key == chosen,
            onSelected: (_) => choose(key),
          );
        }

        Widget chips(List<GoEasyEntry> entries) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries) chip(entry.key, entry.name.of(tag)),
            ],
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const .fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 16,
              children: [
                Text(copy.programConstraint, style: textTheme.titleMedium),
                Text(copy.programConstraintNote, style: muted),
                chip(null, copy.programConstraintNone),
                chips(content.areas),
                chips(content.movements),
              ],
            ),
          ),
        );
      },
    );
  }
}
