---
name: release-notes
description: Draft the user-facing changelog for the next build — TestFlight "What to Test", Play Store "What's new", and the GitHub release body — from the diff since the last shipped version. Use when cutting a release, bumping the version, tagging, or preparing notes for testers. Triggers: "release notes", "changelog", "what to test", "what's new", "cut a release", "tag a version", "TestFlight notes", "store notes", "ship it".
---

# Release notes

One summary, three renderings, three limits. Everything lives in `release_notes/`.

| File                                    | Consumer                                              | Limit                             |
|-----------------------------------------|-------------------------------------------------------|-----------------------------------|
| `release_notes/testflight.txt`          | TestFlight **What to Test**, App Store **What's New** | 4000 chars, but keep it skimmable |
| `release_notes/whatsnew/whatsnew-en-US` | Play Console release notes, uploaded by CI            | **500 chars, hard**               |
| `release_notes/v<version>.md`           | GitHub release body; the archive                      | none                              |

The first two are the *pending* build and get overwritten every time. The archive is written
once, at tag time.

## 1. Find the range

```sh
git describe --tags --abbrev=0 --match 'v*'   # e.g. v1.2.0 — the last thing users got
git log --oneline <tag>..HEAD
```

`<tag>..HEAD` is the range unless the user says otherwise. Tag-to-tag, **not** per build —
every push to `main` ships a dev TestFlight build, and those don't get their own notes.

## 2. Read the diff, not the log

Commit subjects wildly overstate how much happened. `v1.2.0..HEAD` was 113 commits and
225 files, and it is **six lines** of user-facing change — thirty of those commits were one
semantic label each, and together they are a single bullet.

Three sources, in order of signal:

**New strings are the strongest evidence.** A new key in the English ARB is literally a new
word on screen. Nothing else in this repo tells you as directly.

```sh
git diff <tag>..HEAD -- shared/heart_language/lib/l10n/intl_en.arb \
  | grep -E '^\+  "[a-zA-Z]' | sed 's/^+  //' | sort -u
```

Read the *values*, not the key names — the values are the copy the user reads, so they hand you
the vocabulary for the notes. Sort and dedupe; a merge can list the same key twice.

**Where the change landed.** `git diff --name-only <tag>..HEAD`, grouped:

- `lib/presentation/**` — screens and widgets. Visible.
- `shared/heart_state/**` — behaviour: syncing, timers, permissions, lifecycle. Usually visible.
- `shared/heart_charts/**` — visible only if a chart changed shape or gained a control.
- `shared/heart_health/**`, `heart_db/**`, `heart_api/**` — plumbing. Visible only through a
  surface that uses it, so credit the surface, not the package.
- `android/**`, `ios/**` — invisible *except* permissions, entitlements and min SDK, which
  change what the user is asked for and which devices still get the app. Both worth a line.
- `test/**`, `integration_test/**`, `.github/**`, `Makefile`, `scripts/**`, `docs/**`,
  `agents/**`, `.claude/**` — never user-facing.
- `*.g.dart`, `*.mocks.dart`, `intl_en_CA.arb`, `intl_ru.arb` — generated. Never.

**Commit type.** `feat:` and `fix:` are candidates; `refactor:`, `chore:`, `docs:`, `test:`
almost never are. Almost — `refactor: replace \r\n with \n in localization strings` changed
copy, and `fix: prevent notifyListeners on a disposed ChangeNotifier` only ever fixed a test
harness. Check what the commit touched before you trust its prefix either way.

## 3. Filter to what a user can notice

- **One bullet per thing the user can notice**, no matter how many commits it took. Thirty
  accessibility commits → "Buttons, charts and timers announce themselves."
- **Drop bugs that never shipped.** If it was introduced and fixed inside this range, no user
  ever saw it. Grep the range for the fix's commit and check the bug isn't older than `<tag>`.
- **Drop anything gated behind something the user hasn't done.** If it needs a permission,
  say what unlocks it instead of promising it outright.
- **Internal correctness is not a note.** Test flakes, CI, lints, dependency bumps and
  refactors are invisible even when they were most of the work.

### A fix-only cycle gets one line, always

If nothing in the range is a new capability — no new screen, no new control, nothing the user
can now do that they could not before — then the description is **"Bug fixes and performance
improvements."** or a variation of it, in all three renderings. Not a bulleted list of the
things that were wrong.

This is a rule, not a fallback. Enumerating fixes advertises the bugs: it tells a reader who
never hit them that the app had them, and it reads as a changelog rather than a release note.
The store description is not where repairs get itemised.

So the work of reading the diff is still the work — but on a fix-only cycle it decides
**What to test**, not the description. That is where everything you learned from the diff
goes, and it is why the reading matters: the testers cannot know which paths this build put
at risk unless you tell them.

`release_notes/v<version>.md` is the exception and the place for detail. It is the archive, it
is read on purpose by someone who came looking, and it can say exactly what broke and why.

## 4. Write it

Voice: second person, present tense, plain. "Charts now go back through your whole history."

- Never internal names. The reader has never heard of `heart_state`, a `ChangeNotifier`, an ARB
  or a notifier. Name the screen or the thing, not the class.
- No commit prefixes, no PR or issue numbers, no file paths, no version numbers inside the body.
- Lead with the biggest new capability — and if there is no new capability, see the fix-only
  rule above: the description is one line and the detail belongs in **What to test**.
- **Say the platform's own words.** Apple Health / VoiceOver / Settings for TestFlight and the
  App Store; Health Connect / TalkBack / permissions for Play. Same summary, different nouns —
  this is why the two files aren't a copy-paste of each other.
- `testflight.txt` ends with a **What to test** list, and on a fix-only build it is the whole
  point of the file. Name the paths *this build* put at risk, and say what failure looks like
  where that isn't obvious — a moved endpoint shows up as an empty screen, not an error. Cold
  starts, permission prompts, resume-from-background and anything the range touched belong
  here. Testers skim; give them a to-do, not a press release.
- The Play file has no room for that — capabilities and fixes only.

Then check the limit that actually bites:

```sh
wc -m release_notes/whatsnew/whatsnew-en-US   # must be < 500
```

`wc -m` counts characters, `wc -c` counts bytes — Play counts characters, and any localized
copy is multibyte. Over 500 and Play rejects the upload, failing the deploy.

## 5. Show the draft before writing anything

This step is manual on purpose. Print both renderings in chat, with the character count for the
Play one, and say what you dropped and why — the dropped list is where the user catches a
mistake, because they know what shipped and the log doesn't. Wait for their edits. Only then
write the files.

## 6. At tag time

Pushing a `v*` tag is the only thing that ships to real users — every push to `main` ships a
dev build, but those never reach the stores. So the notes describe tag-to-tag, and everything
below has to be **committed before the tag**: prod CI checks out the tagged commit, and a
`whatsnew-en-US` written after tagging isn't in the tree it builds from.

1. Bump `version:` in `pubspec.yaml` by hand (the `+build` suffix is CI's, leave it).
2. Copy the agreed notes to `release_notes/v<version>.md` — the archive and the GitHub release
   body.
3. Leave `testflight.txt` and `whatsnew-en-US` in place; the next cycle overwrites them.
4. Hand off. The user commits, tags, and pushes — that push is the release. Then
   `gh release create v<version> --notes-file release_notes/v<version>.md`.

## Facts and gotchas

- **Both stores are automatic.** The Fastfile reads `release_notes/testflight.txt` into
  `changelog:`. A missing file logs a warning and ships the build without notes rather than
  failing the deploy.
- The lane runs `skip_waiting_for_build_processing: false`, so it waits out Apple's processing.
  Setting it to `true` would still set the changelog — pilot partially waits for that alone —
  but would stop the build reaching the tester groups. Waiting is free on a public repo, and
  the wall-clock only matters because a tag fires both platforms at once.
- **Play notes are automatic.** `google-play-deployment.yml` points `whatsNewDirectory` at
  `release_notes/whatsnew`. The filename must be exactly `whatsnew-en-US`, and that directory
  must hold nothing but `whatsnew-*` files. Add a locale by adding `whatsnew-ru-RU` beside it.
- Play prod uploads to the `internal` track as a **draft**, so notes stay editable in the
  console after the deploy. TestFlight goes to "Primary Testers" immediately.
- The app localizes to `en`, `en_CA` and `ru`, but store notes are their own copy and do **not**
  go through `shared/heart_language`. Don't run the translations skill for these.
- A tag fires iOS and Android prod at once, and both workflows are `cancel-in-progress`.

## Self-check

- [ ] Range starts at the last `v*` tag, not at an arbitrary commit
- [ ] Every bullet is something a user could point at on their screen
- [ ] No new capability in the range → description is "Bug fixes and performance improvements",
      and the diff's findings went into **What to test** instead
- [ ] No internal names, file paths, PR numbers, or commit prefixes survived
- [ ] `wc -m` on the Play file is under 500
- [ ] TestFlight copy says Apple Health/VoiceOver; Play copy says Health Connect/TalkBack
- [ ] `testflight.txt` ends with a **What to test** list
- [ ] The draft was shown, with the dropped list, and the user approved it before writing
