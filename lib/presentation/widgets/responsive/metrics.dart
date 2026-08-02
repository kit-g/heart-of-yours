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
