---
name: analytics
description: Add or change a Firebase Analytics event, parameter or user property, and prove it arrives. The vocabulary lives in one class (Analytics in heart_state); a parameter also has to be registered with GA4 or it is collected and never reportable. Use whenever instrumenting a new surface or flow, adding an event, or asking whether something is being measured. Triggers "add an event", "track this", "analytics", "instrument", "custom dimension", "GA4", "funnel", "what do we measure".
---

# Analytics (Firebase / GA4)

The app's whole event vocabulary is one class: `Analytics` in
`shared/heart_state/lib/src/analytics.dart`. Call sites say what happened in domain terms and it
decides the wire names, the encoding and the parameter keys. Nothing else in the app knows the
SDK exists — `AnalyticsService` is the transport, implemented over `firebase_analytics` in
`lib/core/env/analytics.dart` and by a silent no-op in any run that must not report.

The taxonomy, the rules and what each event means: `docs/2026-09-24.analytics.md`. It is the
contract; this page is how to work on it.

## Three rules that are not negotiable

1. **No health data.** Nothing derived from a `HealthMetric` — weight, heart rate, body fat — is
   a legal argument, as value, bucket or flag. See `docs/2026-09-05.health-data.md`.
2. **Identifiers, never copy.** `provider: 'google'`, never a localized exercise name or a
   workout title. An error **code** is an identifier and fine; an exception *message* is copy and
   may carry an address.
3. **Nothing is awaited and nothing throws.** Reporting never slows down or breaks what it
   reports on. Anything that *computes* an argument from an SDK object guards itself too — see
   `Auth._isNewAccount`.

## Adding an event

1. **Name it in `Analytics`.** A `const` for the event name, `const`s for its parameter keys, and
   a method taking domain types. Event names are `<domain>_<past_tense>`, snake_case, ≤ 40 chars;
   `firebase_`, `google_` and `ga_` are reserved. Do not send `screen_view` — the navigator
   observer already does.
2. **Encode in the method, not at the call site.** GA4 parameter values are `String` or `num`
   only and the SDK asserts on anything else, so a bool goes through `_flag` as `'true'`/`'false'`
   — which also makes it a dimension rather than a metric. An enum carries an `id`; a raw count
   for a user property goes through `_bucket`.
3. **Fire it from where the knowledge is.** Lifecycle events come from the `heart_state`
   notifier that owns the moment (`Workouts`, `Auth`, `Upsync`); intent events — a prompt shown,
   a button meant — come from presentation via `Analytics.of(context)`. The field is
   `Analytics?` and optional, so tests pass nothing.
4. **Register the parameters** — see below. This is the step that gets forgotten.
5. **Write it into `docs/2026-09-24.analytics.md`**, in the tier it belongs to.

## Registering parameters with GA4

**A parameter with no custom dimension is collected and never reportable.** The event count will
look healthy and every breakdown will be empty, which is indistinguishable from the app not
sending it. This is the most expensive mistake available here.

`scripts/ga4.py` owns this. Add a row to the table that matches:

- `EVENT_DIMENSIONS` — string parameters, including bool flags
- `METRICS` — numeric parameters
- `USER_DIMENSIONS` — user properties (GA4 models them as user-scoped dimensions)

Then register on both environments:

```
scripts/ga4.py --env dev  dimensions          # diff; exits 1 while anything is missing
scripts/ga4.py --env dev  dimensions --apply  # creates only what is missing
scripts/ga4.py --env prod dimensions --apply
```

It is idempotent — it reads what exists and sends the difference — so a half-finished run is
fixed by running it again.

## Proving it arrives

Three gates, each of which has silently swallowed a verification attempt:

1. **The run must report.** A debug build sends nothing. Launch with
   `--dart-define=HEART_FORCE_TELEMETRY=true`, which lifts the debug rule for Sentry, Analytics
   and the HTTP wrapper together, and never lifts the Test Lab exclusion.
2. **The project must be linked to a property.** `scripts/ga4.py --env <env> properties` says so
   in its first line. Prod was unlinked until 2026-09-25 and uploaded into nothing without
   erroring.
3. **The app must background.** Firebase on iOS sends the launch burst promptly but holds
   anything logged later in a foreground session until a background transition. `flutter drive`
   kills the app without backgrounding it. Launch any other app on the simulator
   (`xcrun simctl launch <udid> com.apple.mobilesafari`) and the queue flushes in under a minute.

Then `scripts/ga4.py --env dev realtime`. Use `realtime`, not `events`: the date-range reports
lag by hours and a freshly sent event is genuinely absent from them.

`build/telemetry_drive.dart` (gitignored) is the pattern for driving a flow with
`flutter drive --driver=… --keep-app-running`.

## Facts and gotchas

- **Know what the surrounding code mutates.** `workout_finished` counts *after* `saveWorkout`,
  because that method opens with `removeEmptySets`, which drops every unticked set and then any
  exercise left holding none. What survives is what gets stored and shown in history, so it is
  the honest answer; counting first credits a template's fifteen prescribed sets to someone who
  ticked three. Whichever side of a mutation you pick, pick it deliberately — and say why in a
  comment, because the next reader cannot see it.
- **Measure before teardown.** `workout_cancelled` counts while the workout still exists:
  `cancelActiveWorkout` removes it from `_workouts` immediately after, and reading later gives
  zero for everything.
- **GA4 display names** accept alphanumerics, underscores and spaces only. No parentheses; the
  script checks before sending anything, because finding out mid-run half-registers a property.
- **Limits**: 50 custom dimensions, 50 custom metrics, 25 parameters per event, 25 user
  properties. Values ≤ 100 chars, user property values ≤ 36.
- **Never a uid or an email** as a user property — GA4 forbids it and an instance id already
  exists.
- `setAnalyticsCollectionEnabled` **persists across launches**, so a debug run leaves collection
  off until something turns it back on. `initAnalytics` sets it explicitly every launch.
- **Native UI is not drivable.** The file picker, image picker and OS permission dialogs need a
  human — `data_imported`, `avatar_updated` and `notification_permission_result` were verified by
  hand. `flutter_driver` sees the Flutter layer only.
- Do not log from a `build`, a scroll listener or anything per-frame: `logEvent` is a platform
  channel hop on the UI isolate. Log at intent boundaries.

## Self-check

- [ ] the method lives on `Analytics`, and the call site passes domain types, not strings
- [ ] every parameter value is a `String` or a `num` (bools via `_flag`)
- [ ] no health value, no copy, no error *message*
- [ ] a row added to the matching table in `scripts/ga4.py`
- [ ] `dimensions --apply` run against **both** environments, and `dimensions` exits 0
- [ ] `docs/2026-09-24.analytics.md` describes the event in its tier
- [ ] seen arriving in `scripts/ga4.py --env dev realtime` after a forced run and a background
