part of 'workout_detail.dart';

class _TextFieldButton extends StatelessWidget {
  final FocusNode focusNode;
  final Color? color;
  final bool isSetCompleted;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueNotifier<bool> errorState;
  final List<TextInputFormatter>? formatters;

  const _TextFieldButton({
    required this.focusNode,
    required this.errorState,
    this.color,
    required this.isSetCompleted,
    required this.controller,
    this.formatters,
    this.keyboardType = const .numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme, :platform) = Theme.of(context);

    return Focus(
      focusNode: focusNode,
      child: SizedBox(
        height: _fixedButtonHeight,
        child: Padding(
          padding: const .symmetric(horizontal: 2.0),
          child: ListenableBuilder(
            listenable: focusNode,
            builder: (_, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: errorState,
                builder: (_, hasError, _) {
                  return PrimaryButton.shrunk(
                    margin: EdgeInsets.zero,
                    backgroundColor: hasError ? colorScheme.error : color,
                    border: switch ((hasError, focusNode.hasFocus, isSetCompleted)) {
                      (true, true, _) => .all(
                        color: colorScheme.onErrorContainer,
                        width: .5,
                      ),
                      (_, true, true) => .all(
                        color: colorScheme.onTertiaryFixed,
                        width: .5,
                      ),
                      (_, true, false) => .all(
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
                          selectionControls: context.platformSpecificSelectionControls(),
                          textInputAction: TextInputAction.done,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: controller,
                          inputFormatters: formatters,
                          decoration: const InputDecoration.collapsed(hintText: _emptyValue),
                          style: switch (hasError) {
                            true => textTheme.bodyMedium?.copyWith(color: colorScheme.onError),
                            false => textTheme.bodyMedium,
                          },
                          textAlign: .center,
                          cursorHeight: 16,
                          textAlignVertical: switch (platform) {
                            // rendered weird on macos
                            .macOS => .top,
                            // rendered fine, duh
                            _ => TextAlignVertical.center,
                          },
                          maxLines: 1,
                          minLines: 1,
                          cursorColor: switch ((hasError, isSetCompleted)) {
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
