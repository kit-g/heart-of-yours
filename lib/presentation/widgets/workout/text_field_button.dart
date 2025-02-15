part of 'workout_detail.dart';

class _TextFieldButton extends StatelessWidget {
  final FocusNode focusNode;
  final Color? color;
  final ExerciseSet set;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueNotifier<bool> errorState;
  final List<TextInputFormatter>? formatters;

  const _TextFieldButton({
    required this.focusNode,
    required this.errorState,
    this.color,
    required this.set,
    required this.controller,
    this.formatters,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return Focus(
      focusNode: focusNode,
      child: SizedBox(
        height: _fixedButtonHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: ListenableBuilder(
            listenable: focusNode,
            builder: (__, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: errorState,
                builder: (__, hasError, _) {
                  return PrimaryButton.shrunk(
                    margin: EdgeInsets.zero,
                    backgroundColor: hasError ? colorScheme.error : color,
                    border: switch ((hasError, focusNode.hasFocus, set.isCompleted)) {
                      (true, true, _) => Border.all(
                          color: colorScheme.onErrorContainer,
                          width: .5,
                        ),
                      (_, true, true) => Border.all(
                          color: colorScheme.onTertiaryFixed,
                          width: .5,
                        ),
                      (_, true, false) => Border.all(
                          color: colorScheme.onSurfaceVariant,
                          width: .5,
                        ),
                      _ => null,
                    },
                    child: Center(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor: switch (hasError) {
                              true => colorScheme.onError.withValues(alpha: .3),
                              false => null,
                            },
                            selectionHandleColor: switch (hasError) {
                              true => colorScheme.onError.withValues(alpha: .5),
                              false => null,
                            },
                          ),
                          cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
                            primaryColor: switch (hasError) {
                              true => colorScheme.onError.withValues(alpha: .5),
                              false => null,
                            },
                          ),
                        ),
                        child: TextField(
                          textInputAction: TextInputAction.done,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: controller,
                          inputFormatters: formatters,
                          decoration: const InputDecoration.collapsed(hintText: _emptyValue),
                          style: switch (hasError) {
                            true => textTheme.bodyMedium?.copyWith(color: colorScheme.onError),
                            false => textTheme.bodyMedium,
                          },
                          textAlign: TextAlign.center,
                          cursorHeight: 16,
                          textAlignVertical: TextAlignVertical.center,
                          maxLines: 1,
                          minLines: 1,
                          cursorColor: switch ((hasError, set.isCompleted)) {
                            (true, _) => colorScheme.onError,
                            (false, true) => colorScheme.onTertiaryFixed,
                            (false, false) => colorScheme.onSurfaceVariant,
                          },
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onEditingComplete: () {},
                          onTap: () => _selectAllText(controller),
                          onTapOutside: (_) => focusNode.unfocus(),
                        ),
                      ),
                    ),
                    onPressed: () {},
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
