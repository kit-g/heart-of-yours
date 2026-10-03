part of 'workout_detail.dart';

class _TextFieldButton extends StatelessWidget {
  final FocusNode focusNode;
  final Color? color;
  final bool isSetCompleted;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueNotifier<bool> errorState;
  final List<TextInputFormatter>? formatters;
  final String semanticLabel;

  /// A note in the cell's corner, such as the set's RPE ("@8"), read out with
  /// the label.
  final String? badge;

  const new({
    super.key,
    required this.focusNode,
    required this.errorState,
    this.color,
    required this.isSetCompleted,
    required this.controller,
    this.formatters,
    required this.semanticLabel,
    this.badge,
    this.keyboardType = const .numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme, :platform) = Theme.of(context);

    final field = SizedBox(
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
                  // completion no longer changes the field's background, so
                  // focus draws the same quiet outline either way
                  border: switch ((hasError, focusNode.hasFocus)) {
                    (true, true) => .all(
                      color: colorScheme.onErrorContainer,
                      width: .5,
                    ),
                    (false, true) => .all(
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
                      child: Semantics(
                        label: switch (badge) {
                          String badge => '$semanticLabel, $badge',
                          null => semanticLabel,
                        },
                        textField: true,
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
                          cursorColor: switch (hasError) {
                            true => colorScheme.onError,
                            false => colorScheme.onSurfaceVariant,
                          },
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onEditingComplete: () {},
                          onTap: controller.selectAllText,
                          onTapOutside: (_) => focusNode.unfocus(),
                        ),
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
    );

    return Focus(
      focusNode: focusNode,
      child: switch (badge) {
        // the rating rides the cell's corner, outside the pill, so the number
        // keeps the whole width however wide it runs ("255", "@8.5")
        String badge => Stack(
          clipBehavior: .none,
          children: [
            field,
            Positioned(
              top: -6,
              right: 0,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: .all(color: colorScheme.outlineVariant, width: .5),
                    borderRadius: const .all(.circular(6)),
                  ),
                  child: Padding(
                    padding: const .symmetric(horizontal: 4),
                    child: Text(
                      badge,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        null => field,
      },
    );
  }
}
