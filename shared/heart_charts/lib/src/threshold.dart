import 'package:flutter/painting.dart';

/// A horizontal reference line across a chart — a value the series is measured
/// *against* rather than one it contains.
///
/// Its own type rather than `fl_chart`'s `HorizontalLine` so the plotting
/// library stays an implementation detail of this package, the way [Dot] and
/// [LineSeries] already keep it.
class ChartThreshold {
  /// Where the line sits, in the series' own units.
  final double value;

  /// Drawn at the end of the line. Null leaves it unlabelled.
  final String? label;

  /// Whether the series has already reached this value. Drawn solid rather than
  /// dashed — a line still ahead of you and one already behind you are not the
  /// same statement.
  final bool reached;

  final Color? color;

  const new({
    required this.value,
    this.label,
    this.reached = false,
    this.color,
  });

  @override
  bool operator ==(Object other) {
    return other is ChartThreshold &&
        other.value == value &&
        other.label == label &&
        other.reached == reached &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(value, label, reached, color);
}
