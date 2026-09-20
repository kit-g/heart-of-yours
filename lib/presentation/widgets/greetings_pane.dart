import 'package:flutter/material.dart';
import 'package:heart/core/utils/assets.dart';

class GreetingsPane extends StatelessWidget {
  final String title;
  final String body;

  const new({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:primaryColor, :textTheme, :colorScheme, :brightness) = Theme.of(context);

    final fontColor = switch (brightness) {
      Brightness.dark => colorScheme.onPrimaryContainer,
      Brightness.light => colorScheme.onPrimary,
    };
    return Container(
      color: switch (brightness) {
        Brightness.dark => colorScheme.primaryContainer,
        Brightness.light => colorScheme.primary,
      },
      child: Stack(
        children: [
          // A watermark, so it is tinted to the pane's own foreground rather
          // than stamped in the brand's near-black: this ground is
          // `primary`/`primaryContainer`, and every preset picks its own.
          Positioned(
            bottom: 16,
            right: 16,
            child: Image.asset(
              Assets.heart,
              width: 72,
              color: fontColor,
              colorBlendMode: .srcIn,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // scaled to one line rather than wrapped: the titles are
                  // short phrases in every locale, but a single long word —
                  // «С возвращением!» — otherwise breaks mid-word, since
                  // Flutter doesn't hyphenate
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: textTheme.displaySmall?.copyWith(color: fontColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: textTheme.bodyLarge?.copyWith(color: fontColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
