part of 'workout.dart';

/// The template editor, on whatever keeps the template: the user's own
/// [Templates], or a session of a coach's library program (#557).
class TemplateEditor extends StatefulWidget {
  final bool isNewTemplate;

  /// Who keeps the template being edited, and takes the save.
  final TemplateDrafting drafts;

  /// What the page is called and what its name field asks for, when the
  /// template is something more particular than a template.
  final ({String title, String hint})? words;

  const new({
    super.key,
    required this.isNewTemplate,
    required this.drafts,
    this.words,
  });

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:newTemplate, :editTemplate, :templateName) = L.of(context);
    final templates = widget.drafts;
    final title = switch (widget.words) {
      (:final title, hint: _) => title,
      null when widget.isNewTemplate => newTemplate,
      null => editTemplate,
    };

    return ListenableBuilder(
      listenable: templates,
      builder: (context, _) => _page(context, templates, title: title, hint: widget.words?.hint ?? templateName),
    );
  }

  Widget _page(BuildContext context, TemplateDrafting templates, {required String title, required String hint}) {
    final ThemeData(:scaffoldBackgroundColor, :colorScheme, :textTheme) = Theme.of(context);
    final L(:save) = L.of(context);
    if (_controller.text.isEmpty) {
      _controller.text = templates.editable?.name ?? '';
    }

    return PopScope(
      canPop: templates.editable?.isEmpty ?? true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showDiscardTemplateDialog(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: scaffoldBackgroundColor,
          title: Text(title),
          actions: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, _) {
                // a name of spaces is no name: the one saved is trimmed
                final enabled = (templates.editable?.isNotEmpty ?? false) && value.text.trim().isNotEmpty;
                return AnimatedOpacity(
                  opacity: enabled ? 1 : .3,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: PrimaryButton.shrunk(
                      backgroundColor: colorScheme.secondaryContainer,
                      onPressed: switch (enabled) {
                        true => () {
                          Navigator.of(context).pop();
                          templates.saveEditable();
                        },
                        false => HapticFeedback.mediumImpact,
                      },
                      child: Text(save),
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: AppBarTextField(
                hint: hint,
                style: textTheme.titleMedium,
                hintStyle: textTheme.bodyLarge,
                onChanged: (value) {
                  templates.editable?.name = value.trim();
                },
                focusNode: _focusNode,
                controller: _controller,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: WorkoutDetail(
            exercises: templates.editable ?? [],
            // what the plan works, as it grows (#263)
            slivers: [
              SliverToBoxAdapter(
                child: TemplateMuscles(
                  exercises: templates.editable ?? [],
                  padding: const .symmetric(horizontal: 8),
                ),
              ),
            ],
            onDragExercise: templates.append,
            onRemoveSet: templates.removeSet,
            onSetType: templates.setSetType,
            onSetTarget: templates.setSetTarget,
            onAddSet: templates.addSet,
            onRemoveExercise: templates.removeExercise,
            onGroup: templates.group,
            onLeaveGroup: templates.leaveGroup,
            needsCancelWorkoutButton: false,
            onAddExercises: (exercises) async {
              for (final each in exercises) {
                await templates.add(each);
              }
            },
            allowsCompletingSet: false,
            onSwapExercise: templates.swap,
            onTapExercise: (exercise) => showExerciseDetailDialog(context, exercise),
          ),
        ),
      ),
    );
  }

  Future<void> _showDiscardTemplateDialog(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :quitEditing,
      :changesWillBeLost,
      :stayHere,
      :quitPage,
    ) = L.of(
      context,
    );

    return showBrandedDialog(
      context,
      title: Text(
        quitEditing,
        textAlign: TextAlign.center,
      ),
      content: Text(
        changesWillBeLost,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.error,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Center(
                child: Text(stayHere),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  quitPage,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () {
                widget.drafts.discardEditable();
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}
