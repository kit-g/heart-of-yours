part of 'settings.dart';

class _Avatar extends StatelessWidget {
  final String? remote;
  final Uint8List? local;
  final double radius;
  final VoidCallback? onTap;
  final double? progress;

  const _Avatar({
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
          Container(
            height: radius * 2,
            width: radius * 2,
            padding: const EdgeInsets.all(2),
            child: switch ((remote, local)) {
              (null, null) => CircleAvatar(
                  child: Icon(Icons.person_rounded, size: radius),
                ),
              (String? remote, Uint8List? local) => ClipOval(
                  child: AppImage(
                    url: remote,
                    bytes: local,
                    fit: BoxFit.cover,
                  ),
                ),
            },
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
