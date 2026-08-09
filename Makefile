# Single entrypoint for dev and CI.
# CI (.github/workflows/unit-tests.yml) calls these exact targets — the test
# recipe lives here and nowhere else.
#
#   make bootstrap   fresh clone → working setup (deps, codegen, git hooks)
#   make test        the full matrix, exactly as CI runs it
#   make lint        static analysis (the CI gate; formatting is not gated
#                    because the tree predates enforcement — use `make format`)
#   make test-<pkg>  one shared package, e.g. `make test-heart_db`

# Packages with a test suite in the CI matrix.
PACKAGES := heart_api heart_db heart_state heart_charts heart_language
# Packages that need build_runner before their tests (heart_language has no codegen).
CODEGEN_PACKAGES := heart_api heart_db heart_state heart_charts

TEST_TARGETS := $(addprefix test-,$(PACKAGES))
CODEGEN_TARGETS := $(addprefix codegen-,$(CODEGEN_PACKAGES))

.PHONY: bootstrap deps hooks codegen codegen-app lint format test test-app \
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
	cd shared/$* && dart run build_runner build --delete-conflicting-outputs

codegen-app:
	dart run build_runner build --delete-conflicting-outputs

lint:
	flutter analyze

# format only files git knows about: `dart format .` would descend into
# build/ (including vendored SPM package checkouts) — it does not honor
# analyzer excludes and has no exclude flag
format:
	git ls-files -co --exclude-standard '*.dart' | xargs dart format

test: $(TEST_TARGETS) test-app

test-heart_language:
	flutter test shared/heart_language

$(filter-out test-heart_language,$(TEST_TARGETS)): test-%: codegen-%
	flutter test shared/$*

test-app: codegen-app
	flutter test
