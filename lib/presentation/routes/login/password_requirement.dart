part of 'login.dart';

class _Requirement extends StatelessWidget {
  final String label;
  final bool meets;

  const _Requirement({
    required this.label,
    required this.meets,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final color = meets ? colorScheme.tertiary : colorScheme.error;
    return Row(
      spacing: 8,
      children: [
        Icon(
          meets ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          size: 16,
          color: color,
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
