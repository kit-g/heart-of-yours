import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/feedback_button.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// An exercise chart's title row: its title, and the button that puts the
/// chart on the profile dashboard or takes it back off ([DashboardToggle]).
///
/// One widget wherever a chart offers it — an exercise's About tab and a
/// goal's sheet (#626) — so the two look alike and never disagree about the
/// card.
class DashboardChartTitle extends StatelessWidget {
  final String title;
  final Exercise exercise;
  final ChartPreferenceType type;

  const new({super.key, required this.title, required this.exercise, required this.type});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: .ellipsis),
        ),
        DashboardToggle(exercise: exercise, type: type),
      ],
    );
  }
}

/// Puts this exercise+metric chart on the profile dashboard, or takes it back
/// off — the same [ChartPreference] the profile's "New chart" dialog builds,
/// minus the two-step picker, offered right where the metric is on screen.
///
/// Absent until the dashboard has loaded: before then it cannot tell whether
/// the card is already there. Absent too for a metric the exercise's category
/// does not chart, a card its About tab could never show or take off.
class DashboardToggle extends StatelessWidget {
  final Exercise exercise;
  final ChartPreferenceType type;

  const new({super.key, required this.exercise, required this.type});

  @override
  Widget build(BuildContext context) {
    // watched: adding or removing the card flips this button in place
    final charts = Charts.watch(context);
    final L(:addChartToProfile, :removeChartFromProfile, :chartAddedToProfile) = L.of(context);

    if (!charts.initialized || !ChartPreferenceType.chartsByExerciseCategory(exercise.category).contains(type)) {
      return const SizedBox.shrink();
    }

    return switch (charts.exerciseChartOf(exercise.id, type)) {
      null => FeedbackButton.circular(
        tooltip: addChartToProfile,
        onPressed: () async {
          try {
            // the card is not in view from where it was added, so say it landed
            if (await charts.addExerciseChart(exercise.id, type) && context.mounted) {
              snack(context, chartAddedToProfile);
            }
          } catch (error, stacktrace) {
            // nothing was added, and the button still says so
            reportToSentry(error, stacktrace: stacktrace);
          }
        },
        child: const Padding(
          padding: .all(2.0),
          child: Icon(Icons.addchart_rounded, size: 20),
        ),
      ),
      _ => FeedbackButton.circular(
        tooltip: removeChartFromProfile,
        onPressed: () async {
          try {
            await charts.removeExerciseChart(exercise.id, type);
          } catch (error, stacktrace) {
            reportToSentry(error, stacktrace: stacktrace);
          }
        },
        child: Padding(
          padding: const .all(2.0),
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    };
  }
}
