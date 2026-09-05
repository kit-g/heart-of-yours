---
name: review-handoff
description: Review an autonomous agent's work against this repo's definition of done — a worktree under .claude/worktrees/<name> with its HANDOFF.md, or the PR it became. Verifies instead of trusting the handoff: re-runs make lint/test, checks the diff against the ticket, strings, the a11y matrix, large-screen caps, notifier-not-setState, house style, and tree hygiene, then writes REVIEW.md beside HANDOFF.md. Agents run it on their own work before handing off. Triggers: "review the <name> worktree", "review agent work", "review the handoff", "review PR N", "self-review", "is this ready to commit".
---

# Review a handoff

Agent work arrives as an **uncommitted diff in a worktree** plus `HANDOFF.md`; the user reviews,
commits, and opens the PR. This skill is the review. Its stance: **HANDOFF.md is a set of claims,
and every claim gets checked.** The built-in `/code-review` finds bugs in any codebase; this skill
adds what only this repo knows — `docs/handoff.md`, CLAUDE.md, and the house style below.

Two modes, same checklist:

- **Reviewer** (the user, or a session asked to review): report only. Findings go to
  `REVIEW.md`; fixing is a separate ask, because the user is the one who commits.
- **Self-review** (an agent before it writes `HANDOFF.md`): fix what you find, re-run the
  checks, and let `REVIEW.md` record the final state. `HANDOFF.md` then points at it. Anything
  you could not fix becomes an *open end* in the handoff, not a silent pass.

## 1. Locate the target

| Target                        | Where the diff is                                                                                                                                                                 |
|-------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| worktree name (`ui`, `a1`, …) | `W=.claude/worktrees/<name>`; `git -C "$W" add -N . && git -C "$W" diff`                                                                                                          |
| self-review                   | you are already in the worktree: `W=.`                                                                                                                                            |
| PR number                     | `gh pr view N`, `gh pr diff N`. Run checks in the worktree it came from if it still exists (`git worktree list`); otherwise review the diff statically and say so in the verdict. |

Everything below runs with `-C "$W"` or from inside it. A worktree produced by a **container**
agent has a `.dart_tool` pointing at `/opt/flutter` — run `flutter pub get` in it first, or every
tool will complain about "0.0.0-unknown".

Also read, before the diff:

- `$W/HANDOFF.md` — the claims.
- The ticket: `gh issue view N --json title,body -q '.title, .body'` (the number is in the
  handoff's title). In self-review the task text is already in your context.
- `$W/build/agent-screens/` — the agent's screenshots, if any.

## 2. Ticket fidelity

List what the ticket asked for, one line each. Map each line to the diff. Then list what the diff
does that the ticket did **not** ask for — an unrelated fix "along the way", a refactor, a new
dependency. Extra work is not automatically wrong, but it is a decision for the committer, so it
is always a finding, filed under *beyond the ticket*, never buried in the summary.

## 3. Re-verify

Run the checks yourself. Do not accept "621 passed" from the handoff.

```sh
make lint                       # format-check + analyze, with codegen and firebase stubs
make test-<pkg>                 # once per shared/<pkg> the diff touches
make test-app                   # if lib/ or test/ changed
```

Compare with the handoff's verification section. Findings here:

- Any red. Paste the failing output into the review.
- The handoff ran raw `flutter analyze` / `flutter test` / `dart format` instead of the make
  targets. Make is the entrypoint (it wires codegen and the stubs); raw commands can pass
  locally and fail in CI. Flag it — the number may still be right, the process was not.
- New tests: do they exist, and do they test the change rather than the framework? Open them.

## 4. Generic correctness

Invoke `/code-review` at **high** effort with `$W` as the path target, and fold its findings in.
Do not restate what it already covers (null-safety, dead code, duplication, efficiency). Your job
is the rest.

## 5. The repo contract

Each row is a check to run, not a box to tick from the handoff.

| Check                                            | How                                                                                                                                                                                                                                                                                                                                                |
|--------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Strings** — only English is hand-edited        | `git diff -- shared/heart_language`. Hand edits appear only in `lib/l10n/intl_en.arb`. Other `intl_*.arb` and `heart_language_*.dart` change only as the import's output.                                                                                                                                                                          |
| **Strings** — CSV is additive                    | `git diff -- shared/heart_language/scripts/translations.csv` shows only `+` lines (a full-file rewrite means the CSV was regenerated and must be reverted). `grep -c $'\r' scripts/translations.csv` is `0`. `untranslated.json` did not gain entries. Every new key in `intl_en.arb` has a CSV row with every locale filled.                      |
| **Strings** — copy lives in presentation         | Data classes and state notifiers carry identifiers and enums, never words. `grep -n "'[A-Z][a-z]" shared/heart_*/lib` over the diff hunks is a quick tell.                                                                                                                                                                                         |
| **Accessibility** — matrix honesty               | `git diff -- test/a11y_test.dart`. For every skip added or kept, open the cited `file:line`; the reason must describe a real, present defect. For every entry flipped on, `make a11y` proves it. A new screen with no matrix entry is a finding.                                                                                                   |
| **Accessibility** — controls announce themselves | Every new `IconButton`, `InkWell`, `GestureDetector`, or custom button in the diff has a `tooltip` or `Semantics` label, and that label is a translated string, not a literal.                                                                                                                                                                     |
| **Large screens** — pages own their real estate  | `git diff -U0                                                                                                                                                                                                                                                                                                                                      | grep -n "MediaQuery.sizeOf"` — anything outside `presentation/widgets/responsive/` is a finding; page code measures `LayoutBuilder` constraints. |
| **Large screens** — measure *and* cap            | New surfaces use `readableWidth` / `columnsFor` / `dialogWidth` or an explicit `ConstrainedBox`. An `AspectRatio` or grid with no width cap is a finding even if the phone screenshot looks fine — it will ask for 1400pt on an iPad. Where no screenshot exists, a window-size test (`integration_test/responsive_frame_test.dart` pattern) must. |
| **State** — notifiers, not `setState`            | `git diff -U0                                                                                                                                                                                                                                                                                                                                      | grep -c setState` is `0`. Local state is a `ValueNotifier` read through a builder. |
| **Style** — switches                             | Multi-line ternaries and `x != null ? … : …` chains are findings; pattern-matched `switch` expressions are the house form.                                                                                                                                                                                                                         |
| **Style** — naming                               | Dot-shorthand for constructors where the type is known (`.circular(8)`, not `BorderRadius.circular(8)`). No `k`-prefixed constants. Helpers stay private unless something outside the file needs them.                                                                                                                                             |
| **Identity** — exercises                         | Exercise `id` is the identity everywhere; `name` is localized display copy and is never compared, keyed on, or persisted as the identity.                                                                                                                                                                                                          |
| **Dependencies**                                 | A new `pubspec.yaml` entry is a finding to surface (not reject): what it's for, whether the platform folders needed anything, whether `pubspec.lock` moved only for it. A `pubspec.lock` change with no `pubspec.yaml` change is a finding.                                                                                                        |

## 6. Tree hygiene

```sh
git -C "$W" status --short          # everything the committer is about to pick up
git -C "$W" diff --stat
```

- Gitignored config the agent copied in to make the worktree build — `lib/firebase_options*.dart`,
  `env/*.json`, `ios/Env/*/GoogleService-Info.plist` — must **not** appear in the diff. If one
  does, the ignore rules broke; that is a finding above everything else.
- New files show in `git diff` (the agent ran `git add -N .`). Untracked files listed as `??`
  were not, so the reviewer would miss them — flag and run it.
- Screenshots and scratch live under `build/` (ignored). Anything else the agent left behind —
  a debug print, a `TODO(agent)`, a commented-out block — is a finding.
- The worktree branch has no commits of its own (`git -C "$W" log --oneline main..HEAD` is
  empty). The never-commit rule is enforced by a hook, so this is a sanity check, not an
  expectation of trouble.

## 7. Visual pass

UI diffs need eyes on pixels; the widget tree does not catch the failures CLAUDE.md lists.

1. Look at what is in `$W/build/agent-screens/`. Each screenshot should correspond to a surface the
   diff touches; a surface with no screenshot is a finding. Check the things a test can't: does it
   look like the rest of the app, is anything full-bleed on iPad that should be capped, are tap
   targets 48pt.
2. Re-screenshot yourself when the agent was containerized (no simulator), when a screenshot is
   missing, or when one looks wrong. Use the `drive-the-app` skill on the **`agent-iphone`**
   simulator (and an iPad simulator if the surface has a two-pane layout) — never the user's own
   simulators. Build from the worktree, not the main checkout.
3. In self-review you are the agent: the screenshots are yours to take, and they are the evidence
   the handoff cites.

## 8. Open ends → to-dos

Rewrite the handoff's *Open ends* as concrete actions for the committer, one line each, with the
command where there is one (`gh issue comment 72 --body-file build/issue-72-comment.md`). Add any
the review found that the handoff did not mention.

## 9. Write REVIEW.md

At `$W/REVIEW.md` (gitignored, like `HANDOFF.md`). Shape:

```markdown
# Review — <ticket or task>, worktree <name>

**Verdict:** ready to commit | needs changes | needs your eyes (visual / product call)

## Findings
Ranked, most severe first. Each: what, where (`path:line`), why it matters, what to do.
Group *beyond the ticket* items under their own heading so they read as decisions, not defects.

## Verification
What you ran and what happened — commands and outcomes, not adjectives. Where it differs from
HANDOFF.md, say so.

## Contract
One line per row of section 5, plus tree hygiene and visual pass: verified / failed (→ finding) / n-a.

## To-dos for the committer
From section 8.
```

In the terminal, give the verdict and the findings; the file holds the rest. In self-review, after
fixing, re-run sections 3 and 5 and rewrite `REVIEW.md` so it describes the tree as handed off —
a review that describes a state you then changed is worse than none.
