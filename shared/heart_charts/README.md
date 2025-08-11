## Heart Charts

Reusable chart widgets for the Heart app. This package focuses on small, focused
widgets built on top of fl_chart that the rest of the app can compose.

### Why this package exists
- Encapsulate chart presentation and interaction so feature code stays simple.
- Keep charting concerns independent from state/models so any app target can use the same widgets.
- Provide a consistent look and feel (colors, labels, tooltips) across the app.

### What it includes
- HistoryChart: a customizable line chart for showing metric history over time.
- Data types to feed charts:
  - Dot: typed point with x/y and optional tooltip.
  - LineSeries: iterable series with computed min/max Y and built-in tooltip state.
- Shared color palette (ChartColors) for consistent gradients and accents.

### Relationship to other packages
- heart_models: charts visualize values derived from models (exercises, workouts) but have no direct dependency.
- heart_state/heart_db/heart_api: no direct coupling; they provide data that can be rendered by charts.
- heart_language: labels/tooltips text come from callers; charts do not localize themselves.

This separation keeps chart rendering generic and easy to test.

### Quick start
1. Add heart_charts as a dependency within the monorepo (path/workspace resolution). See pubspec for SDK bounds.
2. Import and render a HistoryChart:

```dart
import 'package:flutter/material.dart';
import 'package:heart_charts/heart_charts.dart';

class ExampleChart extends StatelessWidget {
  const ExampleChart({super.key});

  @override
  Widget build(BuildContext context) {
    final series = [
      Dot(0, 20),
      Dot(1, 24),
      Dot(2, 18),
      Dot(3, 28),
    ];

    return SizedBox(
      height: 300,
      child: HistoryChart(
        series: series,
        topLabel: const Text('Weight'),
        bottomAxisLabelStyle: Theme.of(context).textTheme.bodySmall,
        getBottomLabel: (x) => x.isEven ? 'D$x' : '',
        getLeftLabel: (y) => Text(y.toInt().toString(), style: Theme.of(context).textTheme.bodySmall),
        getTooltip: (x, y) => y.toStringAsFixed(0),
      ),
    );
  }
}
```

### Key behaviors
- Auto-bounds: minY and maxY are computed from the provided series (with a small margin).
- Interaction: tap a point to toggle a highlighted indicator and show its tooltip.
- Tooltips and axis labels are provided by the caller via callbacks for full control.

### API overview
- HistoryChart
  - Required: series (Iterable<Dot>)
  - Optional customization:
    - bottomAxisLabelStyle (TextStyle)
    - getBottomLabel: String Function(int x)
    - getLeftLabel: Widget Function(double y)
    - getTooltip: String Function(double x, double y)
    - topLabel: Widget
    - gradientColor1/2/3, indicatorStrokeColor (defaults come from ChartColors)
- Dot(x, y, tooltip?)
- LineSeries
  - Iterable of Dot with lowerBoundaryY/upperBoundaryY and tooltipIndices
  - addTooltipAt(int), removeTooltipAt(int) notify listeners and re-render

### Design notes
- Built on fl_chart’s LineChart for performance and flexibility.
- Stateless usage for callers: widget manages an internal LineSeries for tooltip state.
- Colors are centralized in ChartColors to keep a consistent theme across charts.

### Versioning and installation
- Internal to the Heart monorepo (publish_to: none). Depend via path/workspace within this repo.
- Follows the monorepo’s Dart/Flutter constraints; see pubspec for SDK/Flutter bounds.

### Testing
- Widget tests can pump HistoryChart and verify that:
  - Axis labels/tooltip strings produced by callbacks are rendered.
  - Taps toggle indicator/tooltip state (LineSeries.tooltipIndices).
- Keep charts focused on presentation; data preparation/formatting should happen in callers.

### License and contributions
This package is internal to the Heart project. File issues and contributions within this repository.
