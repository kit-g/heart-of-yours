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
  final double Function(num) axisConverter;
  final Widget Function(Widget child)? dragWrap;

  const new({
    required this.exercise,
    required this.preference,
    required this.exerciseHistoryService,
    required this.onDelete,
    required this.l,
    required this.iconColor,
    required this.textTheme,
    required this.title,
    required this.subtitle,
    required this.axisConverter,
    this.dragWrap,
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
            converter: axisConverter,
            errorState: const SizedBox.shrink(),
            customLabel: Row(
              children: [
                if (dragWrap case final wrap?) ...[
                  wrap(Icon(Icons.drag_indicator, size: 20, color: iconColor)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    '${exercise.name} - ${_chartTypeCopy(context, preference.type)}',
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
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
  new({
    required super.exercise,
    required super.preference,
    required super.exerciseHistoryService,
    required super.onDelete,
    required super.l,
    required super.iconColor,
    required super.textTheme,
    required super.axisConverter,
    super.dragWrap,
  }) : super(
         title: l.emptyChartStateTitle,
         subtitle: l.emptyChartStateBody,
       );
}

class _ErrorState extends _GhostState {
  new({
    required super.exercise,
    required super.preference,
    required super.exerciseHistoryService,
    required super.onDelete,
    required super.l,
    required super.iconColor,
    required super.textTheme,
    required super.axisConverter,
    super.dragWrap,
  }) : super(
         title: l.errorExerciseHistoryTitle,
         subtitle: l.errorExerciseHistoryBody,
       );
}

class _LoadingState extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    // a reserved-height blank, not a spinner: chart data is a local query that
    // lands in a frame or two, so an animated indicator only reads as a blip
    return const SizedBox(height: 300);
  }
}
