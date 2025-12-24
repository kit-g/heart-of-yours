part of 'profile.dart';

class _EmptyState extends StatelessWidget {
  final Exercise exercise;
  final ChartPreference preference;
  final ExerciseHistoryService exerciseHistoryService;
  final Color? iconColor;
  final void Function(ChartPreference) onDelete;
  final L l;
  final TextTheme? textTheme;

  const _EmptyState({
    required this.exercise,
    required this.preference,
    required this.exerciseHistoryService,
    required this.onDelete,
    required this.l,
    required this.iconColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: .center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: .4),
            BlendMode.modulate,
          ),
          child: ExerciseChart(
            emptyState: const SizedBox.shrink(),
            callback: () => exerciseHistoryService.getWeightHistory('', exercise),
            converter: (v) => v.toDouble(),
            errorState: const SizedBox.shrink(),
            customLabel: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text('${exercise.name} - ${_chartTypeCopy(context, preference.type)}'),
                FeedbackButton.circular(
                  tooltip: l.delete,
                  onPressed: () => onDelete(preference),
                  child: Padding(
                    padding: const .all(1.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const .all(32.0),
          child: Column(
            children: [
              Text(
                l.emptyChartStateTitle,
                textAlign: .center,
                style: textTheme?.titleMedium,
              ),
              Text(
                l.emptyChartStateBody,
                textAlign: .center,
                style: textTheme?.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
