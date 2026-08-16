# CLAUDE.md

## Code navigation
Use the Dart MCP LSP (`ToolSearch` → `select:mcp__dart__lsp`) for symbol/type
resolution instead of grep: `resolveWorkspaceSymbol` to find a definition,
`hover`/`signatureHelp` for types and signatures (positions are zero-based).
No `references` command exists — for "find usages", fall back to grep.

## Large screens
iPads and Android tablets are supported, in both orientations, and every new
surface is expected to account for them. Phones stay portrait-locked (see
`_isPhone` in `main.dart`); tablets follow the device.

**Each page owns its own real estate.** Measure `LayoutBuilder` constraints,
not `MediaQuery.sizeOf` — inside a two-pane layout the pane is a fraction of
the window, and the difference is large: the Exercises master pane is ~447pt
while the window reports 1194. `LayoutProvider` is a window-level signal and
exists only for what a page cannot measure its way to: bottom bar vs
`NavigationRail`, and whether the router builds one pane or two.

**Measure *and* cap.** Filling the available width is the default failure
mode, and it is never loud — it just looks wrong. Real examples from this
codebase: a 5:4 `AspectRatio` chart asked for 1392pt of height, a 16:9 photo
for 613pt, and a two-column grid produced a 900pt square card holding two
lines of text. Shared caps live in `presentation/widgets/responsive/`
(`columnsFor`, `readableWidth`) and `dialogWidth` in `core/utils/visual.dart`.

**Screenshot before calling UI work done** — see the `drive-the-app` skill.
Reading the widget tree does not catch any of the above.

Two traps worth knowing when driving the app: route builder closures are
captured when `HeartRouter` is constructed, and an open dialog's page is
cached by `ModalRoute` — changes to either need a hot restart, not a reload.

## Accessibility
Every interactive control announces itself — tooltip or semantic label, and
labels are copy, so they go through the translations flow like any string.
Screens keep their entries in `test/a11y_test.dart`'s screen×guideline
matrix honest: enable what passes, skip what doesn't with a file:line
reason. Patterns, the adoption rule, and what maps to WCAG: `docs/a11y.md`.

## Definition of done
`docs/handoff.md` is the submission checklist for any nontrivial change.
Autonomous agents finish by writing `HANDOFF.md` (worktree root, gitignored)
and, when dispatched from a GitHub issue, commenting the summary on it;
interactive sessions just meet the list.