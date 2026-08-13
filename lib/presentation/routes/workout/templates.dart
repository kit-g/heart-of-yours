part of 'workout.dart';

/// Allows to start a new workout
/// or choose from a set of workout templates or create new ones
class _TemplatesLayout extends StatefulWidget {
  final void Function({bool? newTemplate}) goToTemplateEditor;
  final VoidCallback onNewWorkout;

  const _TemplatesLayout({
    required this.goToTemplateEditor,
    required this.onNewWorkout,
  });

  @override
  State<_TemplatesLayout> createState() => _TemplatesLayoutState();
}

class _TemplatesLayoutState extends State<_TemplatesLayout> {
  /// The template currently in the air, if any.
  ///
  /// Lives here rather than in the card because the unfile strip is the card's
  /// sibling: it only exists while a *filed* template is being dragged. A
  /// notifier rather than state, so picking a card up repaints that strip
  /// instead of every card, folder and grid on the page.
  final _dragged = ValueNotifier<Template?>(null);

  /// The id of the template that just landed, so its card can ease in where it
  /// was dropped instead of appearing there. Cleared once it has.
  String? _landed;

  @override
  void dispose() {
    _dragged.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :textTheme, :colorScheme) = Theme.of(context);
    final L(:startWorkout, templates: copy, :template, :exampleTemplates, :newFolder, :noFolder) = L.of(context);
    final templates = Templates.watch(context);
    final preferences = Preferences.watch(context);
    final unfiled = templates.templatesIn(null).toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          scrolledUnderElevation: 0,
          backgroundColor: scaffoldBackgroundColor,
          pinned: true,
          expandedHeight: 80.0,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            title: Text(startWorkout),
          ),
        ),
        NewWorkoutHeader(openWorkoutSheet: widget.onNewWorkout),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  copy,
                  style: textTheme.headlineSmall,
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: newFolder,
                      // a square tight box rather than `visualDensity`, same as
                      // the movement filter: Material clamps the density's
                      // horizontal adjustment at zero, so it trimmed the height
                      // alone and the splash came out an ellipse
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: .zero,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () {
                        _createFolder(context);
                      },
                    ),
                    if (templates.allowsNewTemplate)
                      PrimaryButton.shrunk(
                        backgroundColor: colorScheme.secondaryContainer,
                        onPressed: () {
                          widget.goToTemplateEditor(newTemplate: true);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, size: 18),
                            Text(template),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final folder in templates.folders)
          _FolderSection(
            key: ValueKey(folder.id),
            folder: folder,
            templates: templates.templatesIn(folder).toList(),
            collapsed: preferences.isFolderCollapsed(folder.id!),
            onToggle: () => preferences.toggleFolderCollapsed(folder.id!),
            onRename: () => _renameFolder(context, folder),
            onDelete: () => _showDeleteFolderDialog(context, folder),
            onDrop: (template) => _file(template, folder),
            card: (template) => _userCard(context, template),
          ),
        // unfiled templates flow right after the folders; the label only exists
        // to keep them from reading as part of the last section. It doubles as
        // the way back out of a folder, so it also appears — over nothing —
        // while a filed template is in the air.
        if (templates.folders.isNotEmpty)
          SliverToBoxAdapter(
            child: _UnfileTarget(
              label: noFolder,
              dragged: _dragged,
              labelled: unfiled.isNotEmpty,
              onDrop: (template) => _file(template, null),
            ),
          ),
        _TemplateGrid(
          templates: unfiled,
          card: (template) => _userCard(context, template),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  exampleTemplates,
                  style: textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        _TemplateGrid(
          templates: templates.samples.toList(),
          card: (template) {
            return _TemplateCard(
              template: template,
              onTap: (template) {
                _showStartWorkoutDialog(context, template, allowsEditing: false);
              },
              onStartWorkout: (template) async {
                await Workouts.of(context).startWorkout(template: template.toWorkout());
                widget.onNewWorkout();
              },
              options: const [.startWorkout],
            );
          },
        ),
      ],
    );
  }

  Widget _userCard(BuildContext context, Template template) {
    final templates = Templates.of(context);
    final card = _TemplateCard(
      template: template,
      onDelete: (template) {
        _showDeleteTemplateDialog(context, template);
      },
      onEdit: (template) {
        templates.editable = template;
        widget.goToTemplateEditor();
      },
      onMove: (template) {
        _showMoveDialog(context, template);
      },
      onStartWorkout: (template) async {
        await Workouts.of(context).startWorkout(template: template.toWorkout());
        widget.onNewWorkout();
      },
      onTap: (template) {
        _showStartWorkoutDialog(context, template);
      },
    );

    return _Landing(
      animate: template.id == _landed,
      onDone: () => _landed = null,
      // Long press rather than plain [Draggable]: the grid scrolls, and an
      // immediate drag would eat every flick that starts on a card. The menu's
      // "Move to folder" stays — dragging is the shortcut, not the only way,
      // and it is the only one on a folder you cannot see from here.
      child: LongPressDraggable<Template>(
        data: template,
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          _dragged.value = template;
        },
        onDragEnd: (_) => _dragged.value = null,
        feedback: _DragPreview(template: template),
        // the card stays in place, faded, so the grid does not reflow under the
        // finger and lose the gap the template came out of
        childWhenDragging: Opacity(opacity: .3, child: card),
        child: card,
      ),
    );
  }

  /// Files [template] where it was dropped, [folder] null meaning out of every
  /// folder. The notifier moves it optimistically and rolls back on rejection.
  Future<void> _file(Template template, TemplateFolder? folder) async {
    HapticFeedback.selectionClick();
    _dragged.value = null;
    // Read back in the rebuild the move itself triggers, which is why this is a
    // plain field and not a notifier: nothing should repaint because of it, and
    // by the time anything reads it the notifier has already asked for a frame.
    _landed = template.id;
    try {
      await Templates.of(context).moveToFolder(template, folder);
    } catch (error) {
      if (mounted) _showFolderError(context, error);
    }
  }

  Future<void> _createFolder(BuildContext context) {
    final templates = Templates.of(context);
    return _showFolderNameDialog(
      context,
      title: L.of(context).newFolder,
      taken: _takenNames(templates),
      onSubmit: templates.createFolder,
    );
  }

  Future<void> _renameFolder(BuildContext context, TemplateFolder folder) {
    final templates = Templates.of(context);
    return _showFolderNameDialog(
      context,
      title: L.of(context).renameFolder,
      initial: folder.name,
      taken: _takenNames(templates, except: folder),
      onSubmit: (name) async {
        if (name == folder.name) return;
        await templates.renameFolder(folder, name);
      },
    );
  }

  /// The folder names already spoken for, lowercased.
  ///
  /// The server settles conflicts case-insensitively, so the field has to read
  /// them the same way. [except] is the folder being renamed — keeping its own
  /// name is not a conflict.
  Set<String> _takenNames(Templates templates, {TemplateFolder? except}) {
    return {
      for (final folder in templates.folders)
        if (folder.id != except?.id) folder.name.toLowerCase(),
    };
  }

  /// Every 400 from a folder call is a name conflict — the only other
  /// rejections are shapes these dialogs cannot produce.
  void _showFolderError(BuildContext context, Object error) {
    final L(:folderNameTaken, :unknownError) = L.of(context);
    final message = switch (error) {
      {'code': 'bad_request'} => folderNameTaken,
      _ => unknownError,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFolderNameDialog(
    BuildContext context, {
    required String title,
    required Set<String> taken,
    required Future<void> Function(String name) onSubmit,
    String? initial,
  }) {
    final ThemeData(:colorScheme) = Theme.of(context);
    return showBrandedDialog(
      context,
      title: Text(
        title,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.folder_outlined,
        color: colorScheme.onPrimaryContainer,
      ),
      // the form owns its controller: the dialog widget outlives the pop by
      // the length of the exit animation, so the caller cannot dispose it. It
      // owns the save for the same sort of reason — see [_FolderNameForm]
      content: _FolderNameForm(initial: initial, taken: taken, onSubmit: onSubmit),
    );
  }

  Future<void> _showMoveDialog(BuildContext context, Template template) {
    final templates = Templates.of(context);
    final L(:moveToFolder, :noFolder, :newFolder) = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);

    // through [_file], so a template filed from the menu lands the same way a
    // dragged one does — and reports the same way when the server says no
    Future<void> move(BuildContext context, TemplateFolder? folder) {
      Navigator.of(context, rootNavigator: true).pop();
      return _file(template, folder);
    }

    return showBrandedDialog(
      context,
      title: Text(
        moveToFolder,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.drive_file_move_outlined,
        color: colorScheme.onPrimaryContainer,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            if (template.folderId != null)
              _MoveOption(
                icon: Icons.folder_off_outlined,
                title: noFolder,
                onTap: () => move(context, null),
              ),
            ...templates.folders.map(
              (folder) {
                return _MoveOption(
                  icon: Icons.folder_outlined,
                  title: folder.name,
                  current: folder.id == template.folderId,
                  onTap: () => move(context, folder),
                );
              },
            ),
            _MoveOption(
              icon: Icons.create_new_folder_outlined,
              title: newFolder,
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _showFolderNameDialog(
                  context,
                  title: newFolder,
                  taken: _takenNames(templates),
                  onSubmit: (name) async {
                    final folder = await templates.createFolder(name);
                    await _file(template, folder);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteFolderDialog(BuildContext context, TemplateFolder folder) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(:deleteFolder, :deleteFolderBody, :cancel, :deleteThis) = L.of(context);
    return showBrandedDialog(
      context,
      title: Text(
        deleteFolder,
        textAlign: TextAlign.center,
      ),
      content: Text(
        deleteFolderBody,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  deleteThis,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () async {
                final templates = Templates.of(context);
                Navigator.of(context, rootNavigator: true).pop();
                try {
                  await templates.deleteFolder(folder);
                } catch (error) {
                  if (context.mounted) _showFolderError(context, error);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDeleteTemplateDialog(BuildContext context, Template template) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :deleteTemplateBody,
      :deleteTemplateTitle,
      :cancel,
      :deleteThis,
      :deleted,
    ) = L.of(
      context,
    );
    return showBrandedDialog(
      context,
      title: Text(
        deleteTemplateTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        deleteTemplateBody,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  deleteThis,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                Navigator.of(context, rootNavigator: true).pop();
                await Templates.of(context).delete(template);
                scaffold.showSnackBar(SnackBar(content: Text(deleted)));
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showStartWorkoutDialog(BuildContext context, Template template, {allowsEditing = true}) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(:cancel, :startWorkout, :startNewWorkoutFromTemplate, :editTemplate) = L.of(context);
    return showBrandedDialog(
      context,
      title: Text(
        startNewWorkoutFromTemplate,
        textAlign: TextAlign.center,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...template.map(
                    (exercise) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${exercise.length} x ${exercise.exercise.name}',
                            style: textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            exercise.exercise.target.value,
                            style: textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      icon: Icon(
        Icons.fitness_center_rounded,
        color: colorScheme.onPrimaryContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            if (allowsEditing)
              PrimaryButton.wide(
                backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
                child: Center(
                  child: Text(editTemplate),
                ),
                onPressed: () {
                  Templates.of(context).editable = template;
                  Navigator.of(context, rootNavigator: true).pop();
                  widget.goToTemplateEditor();
                },
              ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.primaryContainer,
              child: Center(
                child: Text(
                  startWorkout,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                ),
              ),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Workouts.of(context).startWorkout(template: template.toWorkout());
                widget.onNewWorkout();
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// A folder and its templates as one collapsible section: an [ExpansionTile]
/// whose header carries the name, template count and the folder's little menu,
/// and whose body is the grid. The tile owns the fold animation; the collapsed
/// state it starts from — and reports back to — is the caller's.
class _FolderSection extends StatelessWidget {
  final TemplateFolder folder;
  final List<Template> templates;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(Template) onDrop;
  final Widget Function(Template) card;

  const _FolderSection({
    super.key,
    required this.folder,
    required this.templates,
    required this.collapsed,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onDrop,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(:renameFolder, :deleteFolder) = L.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        // off the screen edges, like the workout button above
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // The section measures itself rather than asking the window: inside a
        // two-pane layout this is a fraction of it, and the summary is about
        // the room this tile actually got.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // The whole section takes the drop, header and grid alike: aiming
            // for a 48pt strip while holding a card is not a thing anyone
            // should have to do, and a folder is one place either way.
            return DragTarget<Template>(
              onWillAcceptWithDetails: (details) => details.data.folderId != folder.id,
              onAcceptWithDetails: (details) => onDrop(details.data),
              builder: (context, candidates, _) {
                return DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: _shape,
                    color: switch (candidates.isEmpty) {
                      true => Colors.transparent,
                      false => colorScheme.primaryContainer.withValues(alpha: .5),
                    },
                  ),
                  child: _tile(
                    context,
                    textTheme,
                    colorScheme,
                    renameFolder,
                    deleteFolder,
                    // only what a closed folder hides is worth listing, and
                    // only where there is room for it beside the name
                    summary: switch (collapsed && width >= _summaryWidth) {
                      true => _summary,
                      false => null,
                    },
                    maxSummaryWidth: width / 2,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The first couple of templates a closed folder is holding, and how many
  /// more. Null where there is nothing to say — an empty folder, or one whose
  /// templates are all still unnamed.
  String? get _summary {
    final named = [
      for (final template in templates)
        if (template.name case final String name when name.isNotEmpty) name,
    ];
    final shown = named.take(_summaryNames).toList();
    if (shown.isEmpty) return null;

    final rest = templates.length - shown.length;
    return switch (rest > 0) {
      true => '${shown.join(', ')} +$rest',
      false => shown.join(', '),
    };
  }

  Widget _tile(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
    String renameFolder,
    String deleteFolder, {
    required String? summary,
    required double maxSummaryWidth,
  }) {
    // ExpansionTile clips itself to [shape] but hands its header a plain
    // ListTile, whose ink is a rectangle: rounded at the top two corners and
    // square at the bottom two for as long as the tile is open. The ambient
    // theme is the only way in to that ListTile.
    return ListTileTheme.merge(
      shape: _shape,
      // the folder is the whole leading widget now, so it sits where the
      // chevron used to rather than 40pt further in
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      // No PageStorageKey here, deliberately: the tile would write its bool
      // into PageStorage, and the keyless GridView inside resolves to the
      // same storage identity — restoring "scroll offset" from a bool. The
      // preference is the durable state; a remounted tile reads it back
      // through [collapsed].
      child: ExpansionTile(
        initiallyExpanded: !collapsed,
        onExpansionChanged: (_) => onToggle(),
        // A folder that opens says both things at once, so passing [leading]
        // stands the chevron down — [ExpansionTile] only builds its own when
        // nothing was given. Two glyphs for one boolean was one too many.
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            switch (collapsed) {
              true => Icons.folder_outlined,
              false => Icons.folder_open_outlined,
            },
            key: ValueKey(collapsed),
            size: 20,
            color: colorScheme.outline,
          ),
        ),
        // the default shape is a Border, which paints dividers above and
        // below the open tile
        shape: _shape,
        collapsedShape: _shape,
        iconColor: colorScheme.outline,
        collapsedIconColor: colorScheme.outline,
        // a header, not a list row: 56pt of it above a grid of cards is a band
        // of empty space
        minTileHeight: 44,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: folder.name,
                  style: textTheme.titleMedium,
                  children: [
                    TextSpan(
                      text: '  ${templates.length}',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // The name is [Expanded] and this is not, so the summary states an
            // intrinsic width and the name takes what is left — they cannot
            // overlap. The cap is what keeps a folder of long names from
            // shrinking the name it belongs to down to an ellipsis.
            if (summary case final String copy)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxSummaryWidth),
                child: Text(
                  copy,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<VoidCallback>(
          style: const ButtonStyle(
            visualDensity: VisualDensity(vertical: -3, horizontal: -3),
          ),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_horiz),
          onSelected: (action) => action(),
          itemBuilder: (_) {
            return [
              PopupMenuItem<VoidCallback>(
                value: onRename,
                child: Row(
                  spacing: 4,
                  children: [
                    const Icon(Icons.edit_rounded, size: 16),
                    Text(renameFolder, style: textTheme.titleSmall),
                  ],
                ),
              ),
              PopupMenuItem<VoidCallback>(
                value: onDelete,
                child: Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.delete, size: 16, color: colorScheme.error),
                    Text(
                      deleteFolder,
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.error),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
        children: [
          _TemplateGridBox(templates: templates, card: card),
        ],
      ),
    );
  }
}

/// How wide a folder tile has to be before its closed contents are worth
/// listing beside the name.
///
/// A phone's section is ~377pt: half of that is not a summary, it is a second
/// name competing with the folder's own. Measured against the tile, not the
/// window — in a two-pane layout this pane is a fraction of it.
const _summaryWidth = 520.0;

/// How many templates a folder names before it starts counting them.
const _summaryNames = 2;

/// One row of the move dialog.
///
/// A [ListTile] straight out of the box is a 56pt row with full-bleed square
/// ink — a list's proportions, inside a dialog that is not one.
class _MoveOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool current;
  final VoidCallback onTap;

  const _MoveOption({
    required this.icon,
    required this.title,
    this.current = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: _shape,
      minTileHeight: 44,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      horizontalTitleGap: 12,
      minLeadingWidth: 0,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 20),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: switch (current) {
        true => const Icon(Icons.check_rounded, size: 20),
        false => null,
      },
      onTap: onTap,
    );
  }
}

/// A card easing into the grid it was dropped in.
///
/// Filing a template moves its card from one grid to another, and that mounts a
/// fresh element — so "animate on mount" is exactly "animate on landing", with
/// no need to diff anything. [animate] keeps it to the one card that moved:
/// every other card, and every card on the page's first paint, is already where
/// it belongs and should sit still.
/// The still card is the plain one, deliberately: a still [_Landing] holds no
/// controller and no ticker at all, rather than an idle one per card. It also
/// keeps the animating state's fields off `late final` — a lazy field that
/// nothing read until `dispose` built its controller *there*, and constructing
/// a ticker on a deactivated element crashed on the inherited [TickerMode]
/// lookup.
class _Landing extends StatelessWidget {
  final bool animate;
  final VoidCallback onDone;
  final Widget child;

  const _Landing({
    required this.animate,
    required this.onDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return switch (animate) {
      true => _LandingAnimation(onDone: onDone, child: child),
      false => child,
    };
  }
}

class _LandingAnimation extends StatefulWidget {
  final VoidCallback onDone;
  final Widget child;

  const _LandingAnimation({required this.onDone, required this.child});

  @override
  State<_LandingAnimation> createState() => _LandingAnimationState();
}

class _LandingAnimationState extends State<_LandingAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _eased;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _eased = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    // barely a scale: enough to read as landing rather than as a card growing
    _scale = Tween(begin: .96, end: 1.0).animate(_eased);

    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _eased.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _eased,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// What follows the finger while a template is being dragged.
///
/// A label rather than a copy of the card: the card is as wide as a grid cell,
/// and a full-size one under the finger covers the folder it is aimed at.
class _DragPreview extends StatelessWidget {
  final Template template;

  const _DragPreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Material(
      elevation: 4,
      color: colorScheme.secondaryContainer,
      shape: _shape,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_indicator_rounded, size: 18, color: colorScheme.outline),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                template.name ?? '',
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "No folder" heading, doubling as the way back out of one.
///
/// It is the label over the unfiled templates whenever there are any. While a
/// filed template is in the air it is also a drop target, and appears even with
/// nothing under it — otherwise a folder with every template in it would be a
/// one-way trip from this page.
class _UnfileTarget extends StatelessWidget {
  final String label;
  final ValueNotifier<Template?> dragged;
  final bool labelled;
  final void Function(Template) onDrop;

  const _UnfileTarget({
    required this.label,
    required this.dragged,
    required this.labelled,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: dragged,
      builder: (context, template, _) {
        final offered = template?.folderId != null;
        if (!offered && !labelled) return const SizedBox.shrink();

        return Padding(
          // off the folder above it: the sections carry no margin of their own,
          // so without this the heading sits on the last one's shoulder. Half
          // the usual gap — it labels the grid below it, so it should read as
          // belonging to that rather than as floating between the two. No
          // bottom either; the grid brings its own 8.
          padding: const .fromLTRB(8, 4, 8, 0),
          child: DragTarget<Template>(
            onWillAcceptWithDetails: (details) => details.data.folderId != null,
            onAcceptWithDetails: (details) => onDrop(details.data),
            builder: (context, candidates, _) {
              return DecoratedBox(
                decoration: ShapeDecoration(
                  shape: switch (offered) {
                    true => _shape.copyWith(
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    false => _shape,
                  },
                  color: switch (candidates.isEmpty) {
                    true => Colors.transparent,
                    false => colorScheme.primaryContainer.withValues(alpha: .5),
                  },
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    label,
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.outline),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// The body of the create/rename-folder dialog.
///
/// It saves rather than popping with a name for the caller to save, so a
/// rejected name lands back in the field as an error instead of taking the
/// dialog — and the typing — down with it. The names already in use are known
/// here, so the common conflict is answered as it is typed; the server's 400 is
/// still honoured, for the ones this list cannot see.
class _FolderNameForm extends StatefulWidget {
  final String? initial;
  final Set<String> taken;
  final Future<void> Function(String name) onSubmit;

  const _FolderNameForm({
    this.initial,
    required this.taken,
    required this.onSubmit,
  });

  @override
  State<_FolderNameForm> createState() => _FolderNameFormState();
}

class _FolderNameFormState extends State<_FolderNameForm> {
  late final _controller = TextEditingController(text: widget.initial);

  /// What the server said about the name that was sent, cleared as soon as the
  /// name changes — its verdict was about that one, not the one being typed.
  final _rejected = ValueNotifier<String?>(null);

  final _saving = ValueNotifier(false);

  @override
  void dispose() {
    _controller.dispose();
    _rejected.dispose();
    _saving.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  Future<void> _submit() async {
    // the keyboard's done key bypasses the disabled button
    if (_name.isEmpty || widget.taken.contains(_name.toLowerCase()) || _saving.value) return;

    _saving.value = true;
    try {
      await widget.onSubmit(_name);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (error) {
      if (!mounted) return;
      final L(:folderNameTaken, :unknownError) = L.of(context);
      _saving.value = false;
      _rejected.value = switch (error) {
        {'code': 'bad_request'} => folderNameTaken,
        _ => unknownError,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(:cancel, :save, :folderName, :folderNameTaken) = L.of(context);
    // three things move the form — the text, the server's verdict on it, and
    // whether a save is in flight — and every one of them changes the same
    // three widgets, so they share one builder
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _rejected, _saving]),
      builder: (context, _) {
        final error = switch (widget.taken.contains(_name.toLowerCase())) {
          true => folderNameTaken,
          false => _rejected.value,
        };
        final enabled = _name.isNotEmpty && error == null && !_saving.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving.value,
                textCapitalization: TextCapitalization.sentences,
                // no `border`: the app's InputDecorationTheme already fills the
                // field and rounds its corners
                decoration: InputDecoration(
                  hintText: folderName,
                  errorText: error,
                  // a dialog is narrower than the sentence
                  errorMaxLines: 2,
                ),
                onChanged: (_) => _rejected.value = null,
                onSubmitted: (_) => _submit(),
              ),
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.primaryContainer,
              onPressed: enabled ? _submit : null,
              child: Center(
                child: Text(
                  save,
                  // the explicit color would paint over InkButton's dimmed
                  // disabled foreground, so it applies only when enabled
                  style: switch (enabled) {
                    true => textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                    false => textTheme.bodyMedium,
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
