# Opt-in features

The app as of 1.9.0 is the baseline. Anything built after it asks first: the user decides
whether they want it, and the app takes that answer at its word. The
implementation, a Features section in Settings, is #138.

## The contract

1. **Ask once, in context.** The first time the feature would do something,
   the app asks whether the user wants it. The ask comes then, not at launch
   and not grouped with other asks. The question names what the user gets,
   in one line.
2. **Yes: the whole feature.** No trial, no reduced version, no follow-up
   upsell. If the feature needs an OS permission (notifications, HealthKit,
   Live Activities), the OS prompt comes *after* our yes, never before it.
3. **No: one notice, then silence.** A single line: *you can always turn this
   on in Settings*. After that the app never asks again, and never nudges
   with a badge, a "did you know", or a What's new entry aimed at people who
   said no.
4. **Unanswered counts as no.** An offer the user scrolls past or leaves on
   screen stays up for the rest of that session, so they can still take it.
   From the next launch on it reads as no: the feature stays off and is
   never offered again. There is no notice in that case, because a notice
   the user never asked for would be a second interruption. The Settings
   switch is still the way back.
5. **Off means never built.** A switched-off feature leaves the app exactly
   as it would be if the feature had never been written. That goes past
   hiding its controls: no gap where its card was, no empty tab, no
   leftover divider, no section header over nothing, and no layout sized
   for content that isn't there. The surrounding screens reflow as if the
   feature never existed. This is a design principle, not a cleanup step:
   every design for an opt-in feature has two states, **with** and
   **without**, and the *without* state has to look as deliberate as the
   version of the app before the feature was built. It builds on "controls
   absent rather than dead" in `docs/style.md`.
6. **The switch is always live.** Every opt-in feature has a switch in
   Settings › Features. It is always enabled and works both ways, as often
   as the user likes. Flipping it changes the app on the spot, with no
   restart, no confirmation, and no "takes effect next launch". Turning it
   on there does not ask again, because the switch is the answer.

The answer has three states, not two: *not asked yet*, *on*, and *off*. A
boolean that defaults to false cannot tell "said no" from "never asked", and
that difference is what separates asking once from asking every session.

## The data layer

"Never built" holds below the UI too. Whatever the switch says, nothing in
the feature's data can break the API, the database, or sync:

- **The switch gates presentation, not storage.** Migrations, tables,
  columns, and API fields a feature adds exist whether it is on or off.
  The schema never branches on a preference.
- **Off never deletes.** Turning a feature off keeps its data, and turning
  it back on finds everything where it was. Erasing a feature's data is a
  separate, explicit action, if the feature needs one.
- **Off still round-trips.** A device with the feature off still carries
  its data through sync unchanged, because another device may have it on.
  A field the off device doesn't show is still one it must not drop,
  blank, or overwrite.
- **Derived data is optional.** Anything the feature computes (aggregates,
  caches, indexes) can be skipped while it is off, but it must rebuild
  from source data on the next switch-on. Nothing else may depend on it.
- **Core never reads feature data.** Core code paths must work identically
  whether a feature's data is present, empty, or was written by a version
  of the app that had the feature on. Test the switch both ways with data
  present.

## Core vs opt-in

Core is the app as of **1.9.0**, the baseline: everything that version
shipped is always on and never asked about. That covers logging workouts,
exercises, templates, history, and the account. A new
feature is opt-in unless its ticket says why it is core. "Most people will
want it" is not a reason, because the user can say yes to it.

## Every ticket answers it

Every feature ticket states **Opt-in: yes / no (core, because …)**. If the
ticket doesn't say:

- **Interactive session:** ask the user before building. It is a product
  decision, not an implementation detail.
- **Autonomous agent:** build it as opt-in (the safe default: nothing is
  pushed on anyone), and flag the assumption in `HANDOFF.md` and the issue
  comment.

## Precedent

- The lock-screen workout (#133, `Preferences.lockScreenWorkout`) shipped in
  1.9.0, so it falls under the baseline. It is already off by default with a
  Settings switch, and it keeps that without an ask. It may move into
  Settings › Features, but it needs no retrofit.
- #98 was written as opt-in from the start.
- The watch app (`Feature.watchApp`, #175) is the first feature whose ask is
  not an in-app offer: **opening Heart on the watch is the yes**. Installing
  it is not, because Automatic App Install (on by default) puts it on the
  watch without the user choosing anything. Until that first launch the
  phone sends the watch nothing. Its switch in Settings › Features appears
  only when a paired watch has Heart installed. Switched off, the watch app
  cannot be uninstalled on the user's behalf, so it shows one calm screen
  saying the feature is off on the iPhone — the one exception to "off means
  never built". Like every answer, it syncs: a second phone of the same
  account starts sending to its own watch without asking again.

## Answers follow the account

A signed-in account's answers sync. Each device keeps its own copy, which is
what the app reads, and the account's settings carry one too, under
`extra.features`: `{"muscleMap": {"on": true, "at": "…"}}`. `FeatureSync`
(heart_state) reconciles the two when the account arrives at sign-in and
whenever an answer is given, and the later answer wins on both sides. So a
second phone never asks a question the first one already heard.

- **Only real answers travel.** An unanswered offer and the notice after a no
  stay on the device that showed them.
- **Anonymous sessions stay on the device.** Their answers go up when the
  session becomes an account, as the newer side.
- **Nothing is deleted on either side.** An entry for a feature this version
  doesn't know passes through untouched.
- **The server merges settings rather than replacing them (heart-api#89).**
  Without that, every sign-in, including every 1.9.0 install, would reset them.
- **Health-backed features** still keep their data device-only
  (`docs/2026-09-05.health-data.md`). An answer is not health data, but check
  before syncing one that would be.

## Options (#213)

Some features have parts the user can leave out — the muscle map's figures,
breakdown and heatmap. They are `FeatureOption`s, and they live under the
feature's switch in Settings › Features, unfolded only while it is on.

- **No second ask.** Turning a feature on is the yes, and it turns on in full:
  every option selected. Turning it on again later selects them all again; it
  does not restore an earlier choice.
- **Leaving out the last one turns the feature off.** Choosing none is not a
  state; it is the switch.
- **Live, both ways,** like the switch. A part left out is not built, and the
  screen closes up around the rest: every combination has its *without*.
- **The data layer's rule holds.** Off, the choice is kept, stored and unused.
  It travels with the answer (`FeatureRecord.without`, the `"without"` list in
  `extra.features`), so changing options is a new answer at a new time, and
  the later one wins.
- **Only the switch is an analytics event.** Options send nothing.
- **Notes** can unfold there too: a line a control would not say, such as the
  watch app's pointer to Apple's own Always On setting, which Heart does not
  duplicate.

## Still open (#138)

- Do existing users see the ask for a feature that shipped in an update, or
  only when they first reach it? Rule 1 says when they first reach it.
