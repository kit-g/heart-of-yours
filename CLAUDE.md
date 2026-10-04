# CLAUDE.md

## Code navigation
Use the Dart MCP LSP (`ToolSearch` → `select:mcp__dart__lsp`) for symbol/type
resolution instead of grep: `resolveWorkspaceSymbol` to find a definition,
`hover`/`signatureHelp` for types and signatures (positions are zero-based).
No `references` command exists — for "find usages", fall back to grep.

## Opt-in features
The app as of 1.9.0 is core. Every feature built after it is opt-in: the app
asks once, in context. On yes, the user gets the whole feature. On no or a
dismissal, they see a single "you can turn this on in Settings" notice and are
never asked again. The switch in Settings › Features is always live, both
ways. Off, the app looks as if the feature had never been built (screens
reflow, and every design has a *without* state). Below the UI, the feature's
data stays intact and inert: no schema branches on the switch, off never
deletes, and sync round-trips it untouched. Every feature ticket answers **is
this opt-in?** When a ticket doesn't say, ask the user; autonomous agents
build it as opt-in and flag it. The contract: `docs/opt-in.md`. The framework
itself: #138.

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

## Analytics
Every event the app sends is named once, on `Analytics` in `heart_state`;
call sites pass domain types and it decides the wire names and encoding. A
parameter also has to be registered as a GA4 custom dimension or metric
(`scripts/ga4.py … dimensions --apply`) or it is collected and never
reportable — which looks exactly like the app not sending it. Never a health
value, never copy. The taxonomy: `docs/2026-09-24.analytics.md`; the workflow
and how to prove an event arrives: the `analytics` skill.

## Health data
Anything read from HealthKit / Health Connect is device-only: no server,
no Sentry message, no screenshot, no analytics event. The contract, the
guards that enforce it, and the change protocol (manifest, iOS usage
strings, Play declaration, `site/privacy.html` in heart-api) are in
`docs/2026-09-05.health-data.md`. Read it before touching `Health.tracked`, the
workout write-back, or anything that stores a health value.

## Tickets across the boundary
Each repo owns its own code. A ticket filed in `heart-api` is a **request**: it lists what the app
needs to exist (data, fields, endpoints, behaviour, limits), to be met on a best-effort basis. It
never says how — no file lists, schemas, migrations, method signatures, task checklists or
backend design. Hard constraints go in only when there is an objective reason (a breaking change,
the device-only health rule, a published contract), and the reason goes with them.

Reading a ticket that came from the `heart-api` side, take its specifics as the filer's best
guess, not a spec. Assess it as what this repo has to build to satisfy the need, briefly; don't
review the ticket.

Label every ticket an agent files `agent-filed`, in either repo.

## Style
`docs/style.md` is what the linter cannot say: switch expressions over
ternaries, `Iterable` methods over index loops, dot-shorthand constructors, no
`setState`,
copy only in presentation, controls absent rather than dead. Its entries are
review findings even when `make lint` is clean; add to it when a review
finds a new one.

## Definition of done
`docs/handoff.md` is the submission checklist for any nontrivial change.
Autonomous agents finish by writing `HANDOFF.md` (worktree root, gitignored)
and, when dispatched from a GitHub issue, commenting the summary on it;
interactive sessions just meet the list.