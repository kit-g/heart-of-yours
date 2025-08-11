## Heart DB

Local persistence for the Heart app using SQLite via sqflite. This package provides a concrete implementation of several data service interfaces from `heart_models` to support offline‑first behavior and fast, consistent reads/writes on device.

### Why this package exists
- Provide a single, well‑tested on‑device database for exercises, workouts, templates, timers, and stats.
- Implement the storage‑oriented service interfaces from `heart_models` so UI and state can remain transport‑agnostic.
- Support offline workflows and quick startup by caching domain data locally and exposing query helpers optimized for the app’s needs.

### What it includes
- `LocalDatabase` (primary entry point) that implements:
  - `ExerciseService`
  - `WorkoutService`
  - `TemplateService`
  - `TimersService`
  - `PreviousExerciseService`
  - `StatsService`
- Schema management and migrations for tables:
  - exercises, workouts, workout_exercises, sets, templates, template_exercises, exercise_details, syncs
- Query helpers for:
  - Active workout load/save, workout history, exercise history, PR/records, metric history (weight/reps/distance/duration), previous sets per exercise, per‑exercise rest timers, weekly/aggregate stats

### Relationship to heart_models, heart_state, and heart_api
- `heart_models`: declares the domain types and service interfaces. `heart_db` implements a subset of those interfaces for local persistence.
- `heart_state`: orchestrates UI‑facing state using the interfaces. You can inject `LocalDatabase` anywhere an interface is expected (e.g., `WorkoutService`).
- `heart_api`: provides remote implementations for fetching/syncing data. `heart_db` complements it by storing and serving local data; `heart_state` coordinates between the two.

This layering keeps UI portable and testable: swap in mocks/fakes for services during tests and avoid coupling UI to storage or HTTP details.

### Quick start
- Add `heart_db` as a dependency within the monorepo and initialize it once on app start.
- Inject the resulting `LocalDatabase` instance into `heart_state` modules that need storage.

Example (abbreviated):
- final db = await LocalDatabase.init();
- Provide `db` anywhere the following are required: `ExerciseService`, `WorkoutService`, `TemplateService`, `TimersService`, `PreviousExerciseService`, `StatsService`.
- For lookups that need `ExerciseLookup`, continue to pass the function provided by the Exercises state (see `heart_state` README for ProxyProvider tips).

### Design notes
- SQLite via `sqflite`: chosen for broad platform support and mature tooling.
- Simple migrations: schema created in `onUpgrade` when opening the database; versioning available via `LocalDatabase.init(version: ...)`.
- JSON bridges: complex aggregates (workouts with exercises and sets, templates with staged sets) are materialized via SQL + JSON to map directly into domain models from `heart_models`.
- Key helpers:
  - `getActiveWorkout`, `getWorkout`, `storeWorkoutHistory`, `finishWorkout`
  - `getExercises`, `storeExercises`
  - `getTemplates`, `storeTemplates`, `startTemplate`, `updateTemplate`, `deleteTemplate`
  - `getExerciseHistory`, `getPreviousSets`, `getRecord`
  - `getWeightHistory`/`getRepsHistory`/`getDistanceHistory`/`getDurationHistory`
  - `setRestTimer`, `getTimers`
  - `getWorkoutSummary`, `getWeeklyWorkoutCount`

### Source overview
- lib/heart_db.dart: library entry, exports `LocalDatabase` and wires parts.
- lib/src/db.dart: `LocalDatabase` implementation and transactional helpers.
- lib/src/sql.dart: table DDL and query strings for aggregates/history/metrics.
- lib/src/extensions.dart: small helpers to map snake_case rows to camelCase and decode JSON fields.
- lib/src/constants.dart: internal table name constants.
- lib/src/logger.dart: package logger.

### Versioning and installation
- Dart/Flutter versions follow the monorepo constraints. See the package `pubspec.yaml` for the current SDK bounds.
- This package is internal to the Heart monorepo (`publish_to: none`). Depend on it via path or workspace config inside this repository.

### Testing
- Unit tests live under `shared/heart_db/test/` and cover key queries and workflows (workouts, templates, timers, metrics, exercise history). Use these as examples when integrating.

### License and contributions
This package is internal to the Heart project. File issues and contributions within this repository.
