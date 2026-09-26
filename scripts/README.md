# Scripts

Mostly personal/maintenance tooling; the CI recipe lives in the root `Makefile`
and `.github/workflows/`. The one exception is `test_summary.py`, which the
Test Summary job in `unit-tests.yml` runs.

- `test_summary.py` — renders the dart-test JSON reports the CI test jobs
  produce (make targets with `REPORTS_DIR` set) into one markdown table on the
  workflow run's summary page. Adapted from heart-api's script of the same name.
- `bucket.sh` — builds the web app and syncs it to a personal S3 bucket behind
  CloudFront. Assumes the `personal` AWS profile and `env/new-dev.json`; not
  reusable outside that setup.
- `ga4.py` — reads Google Analytics 4 for one environment, to check what the app
  actually reported against the taxonomy in `docs/2026-09-24.analytics.md`. Event
  counts for the last 30 minutes (`realtime`) or a date range (`events`).
  `--env dev|prod` selects a service-account key under `env/`, so nothing on the
  machine's shared Google credentials is touched; the key needs Viewer on the GA4
  property, which is granted in Analytics admin and not through GCP IAM. See the
  module docstring for the setup.
- `count.sh` — counts Dart lines and reports the two biggest files.
- `android_app_key.sh` — one-time recipe for generating the Android upload
  keystore; the live keystore is fetched from S3 during deploys.
- `unbind.sh` — deletes local branches whose remote branch is gone.
- `seed.sql` — wipes and reseeds a local `heart_db` SQLite database with sample
  workouts for manual testing. Apply manually (e.g. `sqlite3 <db-file> < seed.sql`).
