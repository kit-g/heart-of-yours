import 'dart:math';

/// How many columns [width] should be split into so that none of them is wider
/// than [maxExtent].
///
/// Pages own their own real estate, so they call this with the width they
/// actually got — `constraints.maxWidth`, or a sliver's `crossAxisExtent` —
/// rather than the window width. Inside a two-pane layout those differ by a
/// lot: a detail pane is ~470pt while the window reports 834pt.
///
/// Rounding up means cells only ever get narrower than [maxExtent], never
/// wider, so a browser dragged out to 2560px adds columns instead of stretching
/// the ones it has.
int columnsFor(double width, {required double maxExtent}) {
  assert(maxExtent > 0, 'maxExtent must be positive');
  if (!width.isFinite || width <= 0) {
    return 1;
  }
  return max(1, (width / maxExtent).ceil());
}
