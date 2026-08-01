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
flutter run -t lib/main_driver.dart
```

`lib/main_driver.dart` calls `enableFlutterDriverExtension()` and then delegates to `app.main()`.

**Trap:** that call must come before *anything* touches a binding. It installs its own
`_DriverBinding`; calling `WidgetsFlutterBinding.ensureInitialized()` first makes it throw
`'_debugInitializedType == null': Binding is already initialized`. `bootstrap` calling
`ensureInitialized` afterwards is fine — it returns the existing instance.

Check with `command: get_health` (expect `status: ok`). If it reports the extension is not
enabled, the app is running the plain entrypoint — fall back to simctl for screenshots, and ask
the user to relaunch if you need to interact.

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

## Why bother

Reading the widget tree does not catch: a nav bar painting over a modal sheet, three identical
icons stacked vertically, a tooltip covering the control it explains, or an ink splash squished
into an ellipse. All four were found by screenshotting, none by analysis. Screenshot before
declaring UI work done.