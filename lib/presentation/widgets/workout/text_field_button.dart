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

  /// The seconds of a set's stopwatch while it runs (#171). The cell shows
  /// them ticking, in the accent, in place of the field.
  final ValueNotifier<int>? running;

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
    this.running,
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
                      child: switch (running) {
                        ValueNotifier<int> running => ValueListenableBuilder<int>(
                          valueListenable: running,
                          builder: (_, seconds, _) {
                            // "1:02:03" outgrows a cardio pair's narrow cell
                            return FittedBox(
                              fit: .scaleDown,
                              child: Text(
                                seconds.toDuration(),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontFeatures: const [.tabularFigures()],
                                ),
                              ),
                            );
                          },
                        ),
                        null => Semantics(
                          label: switch (badge) {
                            String badge => '$semanticLabel, $badge',
                            null => semanticLabel,
                          },
                          textField: true,
                          child: TextField(
                            selectionControls: context.platformSpecificSelectionControls(),
                            textInputAction: TextInputAction.done,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            focusNode: focusNode,
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
                      },
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

    // the node is the field's own, so a row can move the keyboard to it
    return Stack(
      clipBehavior: .none,
      children: [
        field,
        Positioned(
          top: -6,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: .8, end: 1.0).animate(animation),
                  alignment: .bottomRight,
                  child: child,
                ),
              );
            },
            child: switch (badge) {
              String badge => ExcludeSemantics(
                key: ValueKey(badge),
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
              null => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}
