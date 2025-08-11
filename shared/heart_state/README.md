## Heart State

State management for the Heart app built on Provider/ChangeNotifier. This package coordinates UI-facing state for authentication, exercises, workouts, templates, stats, timers, preferences, app info, and short-lived alarms. It bridges the domain layer (heart_models) with concrete data sources (e.g., local storage and heart_api) without coupling UI to transport or persistence details.

### Why this package exists
- Centralizes app state and business workflows behind simple, testable ChangeNotifiers.
- Keeps UI widgets thin: widgets subscribe to state and invoke intent methods; I/O is hidden behind service interfaces.
- Separates concerns clearly:
  - heart_models: domain types and service interfaces.
  - heart_state: stateful orchestration, caching, lifecycle, and UX helpers.
  - heart_api or other packages: actual I/O implementations (HTTP, Firebase, etc.).
- Improves sign-out hygiene via a shared reset pattern across modules.

### What it includes
- Barrel export `package:heart_state/heart_state.dart` that re-exports:
  - Alarms: in-app countdown timer for the active exercise, with remains notifier and adjust controls.
  - Auth: Firebase + Google/Apple/email sign-in, account registration via AccountService, avatar upload/removal, deletion scheduling, session token access, and sign-out.
  - Clear: clearState(context) utility to reset all state on sign-out.
  - RemoteConfig: fetch and cache remote config; exposes parsed values like exercisesLastSynced.
  - Exercises: local/remote loading, search & filters, selection set, records and history lookups.
  - AppInfo: app name/version/build via an init hook.
  - Preferences: theme mode, base color (per-user), measurement units (metric/imperial) with conversion helpers.
  - PreviousExercises: quick access to previous sets per exercise.
  - Stats: aggregated workout stats and weekly counts.
  - Templates: CRUD for workout templates, editable staging, sample templates via RemoteConfigService, sync to local/remote.
  - Timers: per-exercise rest timers persisted per user.
  - Workouts: active workout lifecycle, history initialization, local persistence, remote save/delete, and helpers (nextIncomplete, pointAt).

All modules either implement or work with the SignOutStateSentry pattern to cleanly reset state when the user logs out.

### Relationship to heart_models and heart_api
- heart_models provides models and service interfaces (e.g., ExerciseService, RemoteWorkoutService, TemplateService).
- heart_state depends on those interfaces to orchestrate flows and manage UI-facing state.
- heart_api (or any other implementation) fulfills the Remote* services used by heart_state.

This layering keeps UI portable and testable: inject mocks/fakes for services in unit tests without networking.

### Quick start
- Add heart_state as a dependency within the monorepo and set up providers near the app root. Inject concrete services that implement the interfaces from heart_models (for example, heart_api services) and any local storage services.

Example Provider setup (abbreviated):
- Create ChangeNotifierProviders for the state objects you use (Auth, Exercises, Preferences, Alarms, AppInfo, etc.).
- Inject concrete services that implement the interfaces from heart_models (e.g., via heart_api).
- For Workouts/Templates that require an ExerciseLookup, use a ProxyProvider to provide Exercises.lookup to those constructors.

ProxyProvider tip:
- Use ChangeNotifierProxyProvider<Exercises, Workouts> and ChangeNotifierProxyProvider<Exercises, Templates> so those constructors receive exercises.lookup as the lookup function.
- Alternatively, create your own small dependency container and pass a lookup that reaches Exercises.

Common access patterns inside widgets:
- Read once without listening: Auth.of(context)
- Rebuild on changes: Workouts.watch(context)
- Start a workout: Workouts.of(context).startWorkout(name: 'Morning')
- Clear everything on sign-out: clearState(context)

Initialization tips:
- Many modules require a userId before init. After successful login, set userId on modules that need it, then call their init(). For example:
  - Get the user id from Auth
  - Assign it to Exercises, Workouts, Templates, Timers, PreviousExercises
  - Call init() on RemoteConfig, Exercises (optionally with exercisesLastSynced), Workouts, Templates, Timers, PreviousExercises, Stats

Error handling:
- Most constructors accept an optional onError callback. Provide a handler to centralize logging or UI reporting.

### Design notes
- Provider-first: every state object exposes static of(context) and watch(context) helpers for ergonomic access.
- Stateless UI: widgets express intent; state objects mutate models, persist locally, and sync remotely as needed.
- Local-first when possible: e.g., Exercises and Templates load local caches first, then sync from remote.
- Explicit lifecycle: each module implements a cleanup via SignOutStateSentry and/or exposes an onSignOut method; clearState(context) invokes them all.

### Source overview
- lib/heart_state.dart: barrel export for consumers.
- lib/src/*.dart: individual state modules described above.

### Versioning and installation
- Dart/Flutter versions follow the monorepo constraints. See the package pubspec for the current Dart SDK.
- This package is internal to the Heart monorepo (publish_to: none). Depend on it via path or workspace config inside this repository.

### License and contributions
This package is internal to the Heart project. File issues and contributions within this repository.
