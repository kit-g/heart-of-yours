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
