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
