part of 'profile.dart';

/// The profile's own zone: cards the page decides on, above the exercise chart
/// grid the user curates.
///
/// It exists to give the workouts-per-week chart somewhere to live that is not
/// a full-width band. On a phone that changes little; on a tablet it halves the
/// chart and puts the goals card in the space that was empty before. Health
/// cards belong here too, alongside goals rather than among the exercise charts.
class _ProfileArea extends StatelessWidget {
  final WorkoutAggregation workouts;
  final Widget emptyState;

  const new({
    required this.workouts,
    required this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final chart = workouts.isEmpty ? emptyState : WorkoutsAggregationChart(workouts: workouts);

    // The row owns the insets so this band lines up with the chart grid below
    // it: 16 at the outer edges, 10 between. Letting each tile pad itself put
    // the outer edges at 32 and the gutter at 32, against the grid's 16 and 10.
    return SliverToBoxAdapter(
      child: Padding(
        padding: const .symmetric(horizontal: 16),
        // The band's own width decides this, not the window's: a 7" tablet is
        // "wide" by the breakpoint and still only hands this row ~520pt, which
        // halves into two tiles narrower than either tile works at.
        child: LayoutBuilder(
          builder: (_, constraints) => switch (tilesShareRow(constraints.maxWidth)) {
            // in a scrolling column the card can be as tall as it likes
            false => Column(
              children: [
                chart,
                GoalsCard(workouts: workouts, headerHeight: _tileHeaderHeight),
              ],
            ),
            // Side by side, so the chart stops owning a whole row on its own.
            // The card takes the chart's height rule, which lines the two
            // titles up and — more importantly — stops the card growing
            // without limit as goals are added. Past that height its list
            // scrolls.
            true => Row(
              crossAxisAlignment: .start,
              spacing: tileGutter,
              children: [
                Expanded(child: chart),
                Expanded(
                  child: LayoutBuilder(
                    // the chart's own height rule, so the two tiles are the same
                    // box; a part-empty panel beside it beats a short one floating
                    builder: (_, constraints) => SizedBox(
                      height: min(constraints.maxWidth * 4 / 5, _maxChartHeight),
                      child: GoalsCard(workouts: workouts, bounded: true, headerHeight: _tileHeaderHeight),
                    ),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}
