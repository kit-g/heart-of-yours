part of 'workout.dart';

class TemplateEditor extends StatelessWidget {
  final bool isNewTemplate;

  const TemplateEditor({
    super.key,
    required this.isNewTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :colorScheme, :textTheme) = Theme.of(context);
    final L(:newTemplate, :editTemplate, :save, :templateName) = L.of(context);
    final templates = Templates.watch(context);
    final controller = TextEditingController(text: templates.editable?.name ?? '');

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackgroundColor,
        title: Text(isNewTemplate ? newTemplate : editTemplate),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
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
              focusNode: FocusNode(),
              controller: controller,
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
          onAddExercises: (exercises) async {
            for (var each in exercises) {
              await templates.add(each);
            }
          },
        ),
      ),
    );
  }
}

class _TextField extends StatefulWidget {
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
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  @override
  void dispose() {
    widget.focusNode.dispose();
    widget.controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (_, value, __) {
        final needsSuffix = value.text.isNotEmpty;
        return TextField(
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: widget.hintStyle,
            suffixIcon: switch (needsSuffix) {
              false => null,
              true => IconButton(
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  onPressed: () {
                    widget.focusNode.unfocus();
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                ),
            },
            counter: const SizedBox.shrink(), // no counter widget
          ),
          style: widget.style,
          onChanged: widget.onChanged,
          focusNode: widget.focusNode,
          onTapOutside: (_) {
            widget.focusNode.unfocus();
          },
          textCapitalization: TextCapitalization.sentences,
          controller: widget.controller,
          maxLines: 1,
          maxLength: 60,
        );
      },
    );
  }
}
