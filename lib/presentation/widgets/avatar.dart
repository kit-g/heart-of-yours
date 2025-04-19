import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'image.dart';

class EditableAvatar extends StatelessWidget {
  final String? remote;
  final Uint8List? local;
  final double radius;
  final VoidCallback? onTap;
  final double? progress;

  const EditableAvatar({
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

    return GestureDetector(
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
          )
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String? remote;
  final Uint8List? local;
  final double radius;

  const Avatar({super.key, this.remote, this.local, required this.radius});

  @override
  Widget build(BuildContext context) {
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
        _ => CircleAvatar(
            child: Icon(Icons.person_rounded, size: radius),
          ),
      },
    );
  }
}
