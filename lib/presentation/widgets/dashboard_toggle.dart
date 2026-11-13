import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/feedback_button.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Puts this exercise+metric chart on the profile dashboard, or takes it back
/// off — the same [ChartPreference] the profile's "New chart" dialog builds,
/// minus the two-step picker, offered right where the metric is on screen.
///
/// One widget wherever a chart offers it — an exercise's About tab and a
/// goal's sheet (#626) — so the two can never disagree about the card.
class DashboardToggle extends StatelessWidget {
  final Exercise exercise;
  final ChartPreferenceType type;

  const new({super.key, required this.exercise, required this.type});

  @override
  Widget build(BuildContext context) {
    // watched: adding or removing the card flips this button in place
    final charts = Charts.watch(context);
    final L(:addChartToProfile, :removeChartFromProfile, :chartAddedToProfile) = L.of(context);

    // the dashboard card this chart would duplicate, if it is already there.
    // The preference's getter keeps its stale name — the value is the
    // exercise id, the identity that survives localization.
    final existing = charts.exerciseCharts
        .where((each) => each.exerciseName == exercise.id && each.type == type)
        .firstOrNull;

    return switch (existing) {
      null => FeedbackButton.circular(
        tooltip: addChartToProfile,
        onPressed: () {
          charts.addPreference(.exercise(exercise.id, type));
          // the result lives on another tab, so confirm it landed
          snack(context, chartAddedToProfile);
        },
        child: const Padding(
          padding: .all(2.0),
          child: Icon(Icons.addchart_rounded, size: 20),
        ),
      ),
      final preference => FeedbackButton.circular(
        tooltip: removeChartFromProfile,
        onPressed: () => charts.removePreference(preference),
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
