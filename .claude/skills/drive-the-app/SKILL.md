# Driving the running app (simulator or device)

See a change actually rendered, and interact with it, without asking the user to tap things.
Works against an app the user already has running — you rarely need to launch one yourself.

## Connect

1. `mcp__dart__dtd` with `listDtdUris`. Pick the instance whose **Workspace Root is
   `/Users/kitg/apps/heart`** — the others are the Dart SDK's own and are useless here.
2. `mcp__dart__dtd` with `connect` and that URI. Connected apps are listed back; the iPhone
   simulator shows as `Kind: Flutter - Device: iPhone 16 - Package: heart`.

Re-listing is cheap. After any relaunch the URI changes, so reconnect.

## Push your changes

`mcp__dart__hot_reload` (pass `clearRuntimeErrors: true`), then `mcp__dart__get_runtime_errors`
to confirm nothing threw. Reload covers widget-tree and styling edits.

**What hot reload cannot touch** — these need the screen re-entered, or a relaunch:

- Anything fixed when a route is *pushed*: `useRootNavigator`, `showModalBottomSheet` params,
  `DraggableScrollableSheet`'s `initialChildSize`/`snapSizes`. Editing them and reloading changes
  nothing until the sheet is closed and reopened.
- `const` globals.
- Binding setup, and anything in `main()`/`bootstrap` — full relaunch.

## Screenshots

Two paths, and the difference matters:

- **Driver** — `mcp__dart__flutter_driver_command` with `command: screenshot`. Returns the image
  straight into context. Renders the Flutter layer only: no status bar, no notch. Works on
  simulator *and* real devices. Needs the driver entrypoint (below).
- **simctl** — `xcrun simctl io booted screenshot <path>`, then Read the file. Captures the whole
  OS screen including status bar. **Simulator only.** Needs no driver extension, so it is the
  fallback when the app was launched from `lib/main.dart`.

## Interacting (tap, scroll, type)

Requires the app launched with the driver entrypoint:

```
flutter run -t lib/main_driver.dart --flavor dev --dart-define-from-file="env/new-dev.json"
```

**Both flags are load-bearing and neither failure names itself.** Without `--flavor dev` the
Xcode build dies on `None of the input catalogs contained a matching ... "AppIcon"`. Without the
config the app builds, launches, and then throws `UnimplementedError: Valid environments are:
[Env.dev, Env.test, Env.prod]` before `runApp` — so the driver answers `get_health` with
`status: ok` and every command after it fails on *"No root widget is attached"*. `env/` is
gitignored, so none of this is discoverable from the repo.

**Kill the running app first.** `flutter run` builds and installs happily over a running
instance, then fails to launch and exits, leaving the old process up and the new binary
installed — which reads as "the build did nothing".

`lib/main_driver.dart` calls `enableFlutterDriverExtension()` and then delegates to `app.main()`.

**Trap:** that call must come before *anything* touches a binding. It installs its own
`_DriverBinding`; calling `WidgetsFlutterBinding.ensureInitialized()` first makes it throw
`'_debugInitializedType == null': Binding is already initialized`. `bootstrap` calling
`ensureInitialized` afterwards is fine — it returns the existing instance.

Check with `command: get_health` (expect `status: ok`). If it reports the extension is not
enabled, the app is running the plain entrypoint — fall back to simctl for screenshots, and ask
the user to relaunch if you need to interact.

### Driving an app that GoLand did not launch

An app started any other way (`simctl launch`, your own `flutter run`) never registers with DTD,
so `listDtdUris` will not show it. It is still drivable: take the VM service URI the app logs at
startup and connect to it directly.

```
xcrun simctl spawn <UDID> log show --last 1m --predicate 'processImagePath CONTAINS "Runner"' \
  | grep "Dart VM service is listening"
```

Then `mcp__dart__vm_service` with `command: connect` and that URI **rewritten as
`ws://…/ws`** — the logged `http://` form is rejected. Afterwards every
`flutter_driver_command` works, passing the same URI as `appUri`. `hot_reload`/`hot_restart` do
**not**: they need the flutter tool, and fail with `Method not found`.

Finders that work well here:

- `ByTooltipMessage` for `IconButton`s — most in this app set `tooltip`.
- `ByText` for chips, list tiles and menu items. Beware collisions: an exercise named "Lunge"
  also matching a "Lunge" pattern chip is a real case.
- `ByValueKey` against `AppKeys` (`lib/presentation/widgets/keys.dart`).
- `mcp__dart__widget_inspector` with `get_widget_tree` (`summaryOnly: true`) when you need to see
  what is actually on screen before guessing a finder.

## Real devices

Driver commands work over the VM service, which `flutter run` forwards over USB, so tap/scroll/
screenshot all behave the same on a physical phone. Debug or profile builds only — release has no
VM service. `xcrun simctl` does not apply; use the driver screenshot.

## A hot restart does not re-open the database

`sqflite` keeps the database open on the platform side, which a Dart-only restart never touches.
So `LocalDatabase.init` gets the cached handle and **a new migration does not run** — the schema
stays at the old `user_version` however many times you hot restart. Anything touching
`heart_db/lib/src/migrations/` needs a full relaunch to be verified at all.

Check what actually happened rather than trusting the app; a reinstall also moves the data
container, so re-resolve the path instead of reusing one:

```
C=$(xcrun simctl get_app_container <UDID> me.heart-of.ios.dev data)
sqlite3 "$C/Documents/heart.db" "pragma user_version;"
```

## Why bother

Reading the widget tree does not catch: a nav bar painting over a modal sheet, three identical
icons stacked vertically, a tooltip covering the control it explains, or an ink splash squished
into an ellipse. All four were found by screenshotting, none by analysis. Screenshot before
declaring UI work done.