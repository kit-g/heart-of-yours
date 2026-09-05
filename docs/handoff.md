# Definition of done

Applies to any nontrivial change, human or agent. For agents this is the
submission protocol: the run is not finished until every item below is
satisfied or explicitly flagged in the handoff.

## Checklist

1. **Verified** — `make lint` and `make test` (or the targeted `make
   test-<pkg>` suites) pass; record the exact commands and outcomes.
2. **Strings** — every new user-facing string, including tooltips and
   semantic labels, goes through `shared/heart_language` via the
   translations workflow: hand-edit only `intl_en.arb`; other locales flow
   through the CSV import, edited one row at a time.
3. **Accessibility** — new interactive controls announce themselves (label,
   role); screens you touched keep their entries in `test/a11y_test.dart`'s
   screen×guideline matrix honest: enable what now passes, skip what doesn't
   with a file:line reason. Patterns and adoption rule: `docs/a11y.md`.
4. **Large screens** — measure `LayoutBuilder` constraints and cap widths
   (see CLAUDE.md). When you cannot screenshot (containers), a new surface
   gets a window-size widget test instead — the mechanism is in
   `integration_test/responsive_frame_test.dart`.
5. **State** — local widget state is a `ValueNotifier` read through a
   builder, never `setState`.
6. **Git** — never commit or push. Leave work in the tree and run
   `git add -N .` so new files appear in `git diff`.
7. **Self-review** — run the `review-handoff` skill on the finished tree
   before writing the handoff. Fix what it finds, re-run, and leave
   `REVIEW.md` describing the tree as handed off. The reviewer runs the same
   skill, so anything it would catch is cheaper caught here.

## The handoff artifact

Agents write `HANDOFF.md` at the worktree root (gitignored — it is review
material, not product):

- What changed and why, in a few sentences.
- Verification evidence: commands run, results.
- The checklist above, each item marked done / n-a / flagged, with reasons.
- Open ends, and anything that needs a visual/simulator pass on the host.
- A pointer to `REVIEW.md` (also gitignored), the self-review's record.

If the task was dispatched from a GitHub issue, post the same summary as a
comment on that issue — this single outward action is pre-authorized for
agents; nothing else outward is.
