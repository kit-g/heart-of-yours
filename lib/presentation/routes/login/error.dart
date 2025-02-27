part of 'login.dart';

class _Error extends StatelessWidget {
  final String? message;

  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (message) {
        null => const SizedBox.shrink(),
        String error => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.onErrorContainer,
                ),
                Expanded(
                  child: Text(
                    error,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}
