part of 'workout.dart';

class TemplateEditor extends StatefulWidget {
  final bool isNewTemplate;

  const TemplateEditor({
    super.key,
    required this.isNewTemplate,
  });

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :colorScheme, :textTheme) = Theme.of(context);
    final L(:newTemplate, :editTemplate, :save, :templateName) = L.of(context);
    final templates = Templates.watch(context);

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
          title: Text(widget.isNewTemplate ? newTemplate : editTemplate),
          actions: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final enabled = (templates.editable?.isNotEmpty ?? false) && value.text.isNotEmpty;
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
              child: _TextField(
                hint: templateName,
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
            onDragExercise: (_) {
              // todo
            },
            onRemoveSet: templates.removeSet,
            onAddSet: templates.addSet,
            onRemoveExercise: templates.removeExercise,
            needsCancelWorkoutButton: false,
            onAddExercises: (exercises) async {
              for (var each in exercises) {
                await templates.add(each);
              }
            },
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
    ) = L.of(context);

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
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
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
                Templates.of(context).editable = null;
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        )
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String hint;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;
  final TextEditingController controller;

  const _TextField({
    required this.hint,
    this.style,
    this.hintStyle,
    required this.onChanged,
    required this.focusNode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        return ListenableBuilder(
          listenable: focusNode,
          builder: (_, __) {
            final needsSuffix = value.text.isNotEmpty && focusNode.hasFocus;
            return TextField(
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: hintStyle,
                suffixIcon: switch (needsSuffix) {
                  false => null,
                  true => IconButton(
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      onPressed: () {
                        focusNode.unfocus();
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                    ),
                },
                counter: const SizedBox.shrink(), // no counter widget
              ),
              style: style,
              onChanged: onChanged,
              focusNode: focusNode,
              onTapOutside: (_) {
                focusNode.unfocus();
              },
              textCapitalization: TextCapitalization.sentences,
              controller: controller,
              maxLines: 1,
              maxLength: 60,
            );
          },
        );
      },
    );
  }
}
