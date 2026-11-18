/// Shared numbers for pages deciding how much of their width to actually use.
///
/// Pages own their own layout, but they should agree on what "comfortable"
/// means, or the same paragraph ends up a different width on every screen.
library;

/// Roughly 60 characters at body text size — about where a line of prose stops
/// being comfortable to read.
///
/// Caps running text; it is not a general page-width limit. Lists, grids and
/// tables have their own answers.
const readableWidth = 480.0;

/// Widest a workout's set table gets: the exercises, their set rows and Add
/// exercises, on every page that shows one (#592).
///
/// A row is a set number, last time, two values and a tick. Past a phone's
/// width there is nothing more for it to show, only distance between the
/// number and its values; beside an iPad's rail the cells drifted to both
/// edges and Add exercises ran 1,200pt. Wider than any phone held upright, so
/// one shows the table as it always has.
const setTableWidth = 600.0;

/// The gap between two tiles sharing a row, and the number anything wanting to
/// line up with one of them has to subtract before halving the width.
///
/// Shared because the profile's chart/goals band and the health notice below it
/// are separate widgets that have to end on the same line; a literal in each
/// would drift the moment one of them changed.
const tileGutter = 10.0;

/// Narrowest a profile tile may be before two of them stop sharing a row.
///
/// Below it the pair is worse than the stack it replaced: the chart loses its
/// plot to its own axis labels, and a heading that fits in English wraps in
/// every other language.
const minTileWidth = 320.0;

/// Whether a band [width] wide has room for two tiles side by side.
///
/// Measured, never asked of the window: on a 7" tablet the window clears the
/// tablet breakpoint while the band itself is ~520pt, which halves into two
/// tiles too narrow to hold either.
bool tilesShareRow(double width) => width >= minTileWidth * 2 + tileGutter;

/// How wide a line under or over the profile's band runs, in a band [width]
/// wide: one tile while two share a row, so it starts and ends on the tile's
/// edges, and the whole band once they stack.
///
/// A readable measure instead left a banner or a row of prose short of the
/// tile it sat over, off any line the page draws (#687).
double tileWidth(double width) => tilesShareRow(width) ? (width - tileGutter) / 2 : width;
