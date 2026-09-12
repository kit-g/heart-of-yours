import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';

import 'image.dart';

class EditableAvatar extends StatelessWidget {
  final String? remote;
  final Uint8List? local;
  final double radius;
  final VoidCallback? onTap;
  final double? progress;

  const new({
    super.key,
    this.onTap,
    this.remote,
    this.local,
    this.radius = 48,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);

    return Semantics(
      button: true,
      label: L.of(context).changeProfilePhoto,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            if (progress case double progress)
              SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                  color: colorScheme.primaryContainer,
                ),
              ),
            Avatar(
              radius: radius,
              local: local,
              remote: remote,
              bordered: true,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.edit_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? remote;
  final Uint8List? local;
  final double radius;

  /// Rings the placeholder as well as filling it.
  ///
  /// The account screen's avatar is a control — tapping it picks a photo — and
  /// while it is empty the ring is what says so. The profile's is a label for
  /// the row it sits in, so it stays flat.
  final bool bordered;

  const new({super.key, this.remote, this.local, required this.radius, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :dividerColor) = Theme.of(context);

    return Container(
      height: radius * 2,
      width: radius * 2,
      padding: const EdgeInsets.all(2),
      child: switch ((remote, local)) {
        (_, Uint8List local) => ClipOval(
          child: AppImage(
            bytes: local,
            fit: BoxFit.cover,
          ),
        ),
        (String remote, _) when remote.startsWith('https') => ClipOval(
          child: AppImage(
            url: remote,
            fit: BoxFit.cover,
          ),
        ),
        // Stated rather than inherited. [CircleAvatar]'s Material default fill
        // is `primaryContainer`, and the preset rework maps that role onto
        // `surface` — the page's own colour — so the placeholder went invisible
        // without anything here changing. The fill and the glyph are a
        // placeholder's, not content's: the neutral container and muted ink.
        _ => Container(
          alignment: .center,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: .circle,
            // dividerColor, not outlineVariant: this preset puts the latter
            // within a shade of the fill, so the ring vanished into it. The
            // health notice and the chart cards draw their edges the same way.
            border: switch (bordered) {
              true => Border.all(color: dividerColor),
              false => null,
            },
          ),
          child: Icon(
            Icons.person_rounded,
            size: radius,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      },
    );
  }
}
