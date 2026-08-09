# Single entrypoint for dev and CI.
# CI (.github/workflows/unit-tests.yml) calls these exact targets — the test
# recipe lives here and nowhere else.
#
#   make bootstrap   fresh clone → working setup (deps, codegen, git hooks)
#   make test        the full matrix, exactly as CI runs it
#   make lint        the CI gate: static analysis + format check
#                    (`make format` fixes what the check reports)
#   make test-<pkg>  one shared package, e.g. `make test-heart_db`

# Packages with a test suite in the CI matrix.
PACKAGES := heart_api heart_db heart_state heart_charts heart_language
# Packages that need build_runner before their tests (heart_language has no codegen).
CODEGEN_PACKAGES := heart_api heart_db heart_state heart_charts

TEST_TARGETS := $(addprefix test-,$(PACKAGES))
CODEGEN_TARGETS := $(addprefix codegen-,$(CODEGEN_PACKAGES))

.PHONY: bootstrap deps hooks codegen codegen-app lint format format-check test test-app \
        $(TEST_TARGETS) $(CODEGEN_TARGETS)

bootstrap: hooks deps codegen codegen-app
	@echo "Ready. Note: lib/firebase_options.dart and lib/firebase_options_prod.dart"
	@echo "are gitignored and required to build the app (not to run tests) — see README."

deps:
# CI installs the version pinned in .flutter-version; warn on local drift
	@installed=$$(flutter --version | head -1 | awk '{print $$2}'); \
	pinned=$$(cat .flutter-version); \
	[ "$$installed" = "$$pinned" ] || \
	  echo "warning: local Flutter $$installed differs from pinned $$pinned (.flutter-version)"
	flutter pub get
# sqlite3 3.x provides its native lib via Dart build hooks; tests opening a real DB need it
	flutter config --enable-native-assets

hooks:
	git config core.hooksPath .githooks

codegen: $(CODEGEN_TARGETS)

$(CODEGEN_TARGETS): codegen-%:
	cd shared/$* && dart run build_runner build

codegen-app:
	dart run build_runner build

# `flutter analyze` must resolve the gitignored Firebase options; on machines
# without Firebase credentials (CI), stub them. `flutterfire configure`
# produces the real ones (see README) — when present, these are no-ops.
# Note: analysis also needs generated mocks — CI runs `make codegen codegen-app`
# before lint; dev machines have them after bootstrap or any test run.
lib/firebase_options.dart lib/firebase_options_prod.dart:
	printf '%s\n' \
	  '// Stub written by make so `flutter analyze` resolves this import.' \
	  '// The real, gitignored file comes from `flutterfire configure` — see README.' \
	  "import 'package:firebase_core/firebase_core.dart';" \
	  '' \
	  'class DefaultFirebaseOptions {' \
	  '  static FirebaseOptions get currentPlatform => throw UnimplementedError();' \
	  '}' > $@

lint: format-check lib/firebase_options.dart lib/firebase_options_prod.dart
	flutter analyze

format-check:
	git ls-files -co --exclude-standard '*.dart' | xargs dart format --output=none --set-exit-if-changed

# format only files git knows about: `dart format .` would descend into
# build/ (including vendored SPM package checkouts) — it does not honor
# analyzer excludes and has no exclude flag
format:
	git ls-files -co --exclude-standard '*.dart' | xargs dart format

test: $(TEST_TARGETS) test-app

# With REPORTS_DIR set (CI), each suite also writes a dart-test JSON report
# there for the Test Summary job to aggregate; locally nothing changes.
# $(call suite_test,<path or empty for the app>,<report name>)
define suite_test
$(if $(REPORTS_DIR),mkdir -p "$(REPORTS_DIR)" && )flutter test $(1) $(if $(REPORTS_DIR),--file-reporter="json:$(REPORTS_DIR)/$(2).json")
endef

test-heart_language:
	$(call suite_test,shared/heart_language,heart_language)

$(filter-out test-heart_language,$(TEST_TARGETS)): test-%: codegen-%
	$(call suite_test,shared/$*,$*)

test-app: codegen-app
	$(call suite_test,,app)
