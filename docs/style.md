# House style

What the linter cannot say. `make lint` enforces the mechanical part
(`analysis_options.yaml`: trailing commas, const, single quotes, null-aware
elements, declaring parameters…); this page is the rest — the shapes that get a
change sent back even when analysis is clean. Each entry is a no-no and the
form that replaces it. Add to it when a review finds a new one.

## Control flow

**No multi-line ternaries, and no negative framing.** A `?:` is fine when it
fits on one line. Anything longer, or anything shaped `x != null ? a : b`, is a
`switch` expression with the positive case first — it reads top-down and
matches on the value's shape.

```dart
// no
final g = accent != null
    ? solid(accent)
    : fallback();

// yes
final g = switch (accent) {
  Color c => solid(c),
  null => fallback(),
};
```

A one-line `??` fallback is fine.

**No C-style index loops.** `for (var i = 0; i < n; i++)` is not how this
codebase walks anything. Iterate the collection; when the index matters, ask
for it; when there is only a count, generate.

```dart
// no
for (var i = 0; i < screens; i++) _Dot(active: i == page),

// yes
for (final (i, _) in screens.indexed) _Dot(active: i == page),
...List.generate(screens.length, (i) => _Dot(active: i == page)),
```

The one place an index loop earns its keep is index *arithmetic* — bucketing a
series into `n` slices — and even then it lives in a small helper, not in a
`children:` list.

## Naming and notation

- **Dot-shorthand for constructors**, not only enums, wherever the type is
  inferred: `const .only(left: 16)`, `.circular(8)`, `mainAxisAlignment:
  .center`. Not `EdgeInsets.only(...)` when the parameter already says
  `EdgeInsetsGeometry`.
- **No `k`-prefixed constants.** `historyChartLeftAxisSize`, not
  `kHistoryChartLeftAxisSize`.
- **Private by default.** Helpers, widgets and constants are `_named` unless
  something outside the file needs them. Do not pollute a library's namespace
  to make a test easier; test through the public surface.
- **Nullable parameters are never `required`.** `Color? color` that every
  caller must pass as `null` is wrong — make it optional and omit it at call
  sites.
- Identifiers name the *thing*: an exercise is its `id`, never its `name`
  (names are localized display copy — see "Copy").

## State

**No `setState`.** It repaints the whole `State`'s subtree for a change that
usually touches one widget. Hold the value in a `ValueNotifier` (or a
`ChangeNotifier`) on the `State`, dispose it, and wrap only the widgets that
depend on it in a `ValueListenableBuilder`. Several values driving the same
widgets: one `ListenableBuilder` over `Listenable.merge([...])`, not nested
builders. A plain field is fine only for something that must *not* cause a
frame.

App-level state lives in the `heart_state` notifiers and is read through
`X.of(context)` (no rebuild) or `X.watch(context)` (rebuild); `Selector` when
one field is enough.

## Copy

**Presentation owns copy.** A model, a state class, an enum in `shared/`
carries an identifier — `horizontal_press`, `moderate` — never words. The
presentation layer turns it into copy next to the localizations, via an
extension taking `L`. `shared/heart_state` cannot reach `L` at all, so any
string built there is permanently unlocalizable.

Every user-facing string, tooltips and semantic labels included, is an `L`
getter that went through the translations workflow (`translations` skill):
hand-edit `intl_en.arb` only; every other locale flows through the CSV, one
row at a time. A literal in a widget is a finding.

## Widgets and layout

- **Measure, and cap.** Pages measure `LayoutBuilder` constraints, never
  `MediaQuery.sizeOf`, and cap what they fill: `readableWidth`, `columnsFor`,
  `dialogWidth`. See CLAUDE.md, *Large screens*, for the failures this
  prevents.
- **Every control announces itself** — a `tooltip` or a `Semantics` label, and
  it is copy, so it is an `L` getter. Screens keep their row in the
  `test/a11y_test.dart` matrix honest (`docs/a11y.md`).
- **Material defaults are not decisions.** Stock colours, densities and
  shapes get called out in review; contrast and affordance are chosen. Buttons
  are the `PrimaryButton` family and the theme's tokens, not ad-hoc
  `ElevatedButton`s with inline colours.
- **Absent, not dead.** A control that cannot work in the current state (no
  account, no server) is left out, not rendered disabled or made to fail on
  tap — a row that apologises when tapped is a reminder in disguise.

## UX

The governing rule is **annoy the user as little as possible**. It settles
most design arguments:

- No confirm dialog for a reversible action; no dialog at all where a live,
  undoable change will do. The dialog is itself the annoyance.
- No nags, banners, or reminders. A feature that needs an account explains
  itself in the one place that opens it, once.
- Refuse an ambiguous action rather than guess behind a confirmation.
- When a control needs a footnote to be understood, change the control, not
  the footnote.
- Prefer visible, clearable, session-scoped state to a persistent setting
  that becomes invisible three months later.

## Comments and leftovers

Comments say *why* — the constraint, the bug this shape avoids, the thing
that looks redundant and isn't. Not what the next line does. No
`TODO(agent)`, no commented-out code, no `debugPrint` left behind; a genuine
open end goes in the handoff, not the source.
