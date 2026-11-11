part of 'coaching.dart';

/// The programs a coach writes for clients, apart from their own training
/// (#557): the library, the most recently changed first.
class CoachProgramsPage extends StatefulWidget {
  final VoidCallback onYourTraining;
  final void Function(String programId) onOpen;
  final VoidCallback onNew;

  const new({super.key, required this.onYourTraining, required this.onOpen, required this.onNew});

  @override
  State<CoachProgramsPage> createState() => _CoachProgramsPageState();
}

class _CoachProgramsPageState extends State<CoachProgramsPage> {
  @override
  void initState() {
    super.initState();
    // read on opening, as the roster is: the library is the server's
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CoachLibrary.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final library = CoachLibrary.watch(context);
    final CoachProgramsPage(:onYourTraining, :onOpen, :onNew) = widget;
    return _CoachingPage(
      title: l.coachingPrograms,
      onYourTraining: onYourTraining,
      actions: [
        if (library.programs.isNotEmpty)
          IconButton(
            key: AppKeys.coachingNewProgram,
            tooltip: l.newProgram,
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
          ),
      ],
      child: switch ((library.status, library.programs)) {
        (.idle || .loading, []) => const Center(child: CircularProgressIndicator.adaptive()),
        (.failed, []) => _Empty(
          icon: Icons.cloud_off_rounded,
          title: l.coachingProgramsFailed,
          action: OutlinedButton(onPressed: library.load, child: Text(l.retry)),
        ),
        (_, []) => _Empty(
          icon: Icons.event_repeat_rounded,
          title: l.coachingNoPrograms,
          body: l.coachingNoProgramsBody,
          action: FilledButton.icon(
            key: AppKeys.coachingNewProgramEmpty,
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            label: Text(l.newProgram),
          ),
        ),
        (_, final programs) => RefreshIndicator.adaptive(
          onRefresh: library.load,
          child: ListView(
            padding: const .symmetric(vertical: 8),
            children: [
              for (final program in programs)
                _LibraryTile(program: program, unsaved: library.unsaved(program.id), onTap: () => onOpen(program.id)),
            ],
          ),
        ),
      },
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final CoachProgram program;

  /// Whether its last change is still only on this device.
  final bool unsaved;
  final VoidCallback onTap;

  const new({required this.program, required this.unsaved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final date = DateFormat.yMMMd(l.localeName).format(program.updatedAt.toLocal());
    return ListTile(
      key: AppKeys.coachingLibraryProgram(program.id),
      title: Text(program.name, maxLines: 1, overflow: .ellipsis),
      subtitle: Text(l.coachingProgramVersion(program.version, date)),
      trailing: switch (unsaved) {
        true => Icon(Icons.cloud_off_rounded, color: colorScheme.error, semanticLabel: l.coachingProgramUnsaved),
        false => const Icon(Icons.chevron_right_rounded),
      },
      onTap: onTap,
    );
  }
}
