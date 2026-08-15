import 'dart:math';

/// Computes rounded axis bounds and a tick interval so gridlines land on
/// human-friendly values (…, 10, 12, 14 …) instead of the data-driven fractions
/// a chart library places by default.
///
/// [dataMin]/[dataMax] are the series' actual value range. The result always
/// contains that range; when a value sits exactly on a computed bound the bound
/// gets a step of headroom so a dot marker isn't clipped at the edge.
///
/// [stepCandidates], when given (ascending), constrains the interval to one of
/// those values — e.g. duration charts pass `[15, 30, 60, 300, …]` seconds so
/// ticks read 30s/1m rather than an arbitrary 20s. When null, a generic
/// 1/2/5·10ⁿ "nice number" is derived from the range.
({double min, double max, double interval}) niceYAxis(
  double dataMin,
  double dataMax, {
  int targetTicks = 5,
  List<double>? stepCandidates,
}) {
  if (!(dataMax > dataMin)) {
    // flat or single-point series — a small symmetric band around the value
    final base = dataMax.abs() < 1 ? 1.0 : dataMax.abs();
    final step = _pickStep(base, targetTicks, stepCandidates);
    return (min: dataMax - step, max: dataMax + step, interval: step);
  }
  final step = _pickStep(dataMax - dataMin, targetTicks, stepCandidates);
  var lo = (dataMin / step).floorToDouble() * step;
  var hi = (dataMax / step).ceilToDouble() * step;
  // guarantee at least half a step of breathing room at each end so a peak or
  // trough — and its dot marker — never sits against the chart edge
  if (hi - dataMax < step / 2) hi += step;
  if (dataMin - lo < step / 2) lo -= step;
  return (min: lo, max: hi, interval: step);
}

/// Smallest step that fits [range] into ~[targetTicks] gridlines: a supplied
/// candidate (e.g. duration steps) when given, else a 1/2/5·10ⁿ nice number.
double _pickStep(double range, int targetTicks, List<double>? candidates) {
  final span = targetTicks > 1 ? targetTicks - 1 : 1;
  if (candidates != null && candidates.isNotEmpty) {
    for (final candidate in candidates) {
      if (range / candidate <= span) return candidate;
    }
    return candidates.last;
  }
  return _niceNum(_niceNum(range, round: false) / span, round: true);
}

/// Rounds [range] to a 1/2/5·10ⁿ value — the classic "nice numbers for graph
/// labels" from Heckbert. [round] snaps to the nearest such number; otherwise it
/// takes the ceiling, used to nice-ify the overall range before deriving a step.
double _niceNum(double range, {required bool round}) {
  if (range <= 0) return 1;
  final exponent = (log(range) / ln10).floorToDouble();
  final fraction = range / pow(10, exponent);
  final nice = round
      ? (fraction < 1.5
            ? 1.0
            : fraction < 3
            ? 2.0
            : fraction < 7
            ? 5.0
            : 10.0)
      : (fraction <= 1
            ? 1.0
            : fraction <= 2
            ? 2.0
            : fraction <= 5
            ? 5.0
            : 10.0);
  return nice * pow(10, exponent).toDouble();
}
