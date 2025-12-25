part of 'profile.dart';

class _GhostState extends StatelessWidget {
  final Exercise exercise;
  final ChartPreference preference;
  final ExerciseHistoryService exerciseHistoryService;
  final Color? iconColor;
  final void Function(ChartPreference) onDelete;
  final L l;
  final TextTheme? textTheme;
  final String title;
  final String subtitle;

  const _GhostState({
    required this.exercise,
    required this.preference,
    required this.exerciseHistoryService,
    required this.onDelete,
    required this.l,
    required this.iconColor,
    required this.textTheme,
    required this.title,
    required this.subtitle,
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
                title,
                textAlign: .center,
                style: textTheme?.titleMedium,
              ),
              Text(
                subtitle,
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

class _EmptyState extends _GhostState {
  _EmptyState({
    required super.exercise,
    required super.preference,
    required super.exerciseHistoryService,
    required super.onDelete,
    required super.l,
    required super.iconColor,
    required super.textTheme,
  }) : super(
         title: l.emptyChartStateTitle,
         subtitle: l.emptyChartStateBody,
       );
}

class _ErrorState extends _GhostState {
  _ErrorState({
    required super.exercise,
    required super.preference,
    required super.exerciseHistoryService,
    required super.onDelete,
    required super.l,
    required super.iconColor,
    required super.textTheme,
  }) : super(
         title: l.errorExerciseHistoryTitle,
         subtitle: l.errorExerciseHistoryBody,
       );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 300,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
