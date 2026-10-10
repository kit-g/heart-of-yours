# Single entrypoint for dev and CI.
# CI (.github/workflows/unit-tests.yml) calls these exact targets — the test
# recipe lives here and nowhere else.
#
#   make bootstrap   fresh clone → working setup (deps, codegen, git hooks)
#   make test        the full matrix, exactly as CI runs it
#   make lint        the CI gate: static analysis + format check
#                    (`make format` fixes what the check reports)
#   make test-<pkg>  one shared package, e.g. `make test-heart_db`
#   make profiles    iOS signing profiles for one environment (ENV=dev|prod)

# Packages with a test suite in the CI matrix.
PACKAGES := heart_api heart_db heart_state heart_charts heart_language heart_health
# Packages that need build_runner before their tests. heart_language's codegen
# is the translation import instead (codegen-heart_language, below).
CODEGEN_PACKAGES := heart_api heart_db heart_state heart_charts heart_health

TEST_TARGETS := $(addprefix test-,$(PACKAGES))
CODEGEN_TARGETS := $(addprefix codegen-,$(CODEGEN_PACKAGES))

.PHONY: bootstrap deps hooks codegen codegen-app codegen-heart_language lint format format-check test test-app \
        test-scripts profiles reclaim $(TEST_TARGETS) $(CODEGEN_TARGETS)

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
# the translation sources merge by key (.gitattributes, scripts/l10n_merge.py)
	git config merge.l10n-arb.name "key-aware merge of an ARB"
	git config merge.l10n-arb.driver "python3 scripts/l10n_merge.py arb %O %A %B"
	git config merge.l10n-csv.name "row-aware merge of the translations CSV"
	git config merge.l10n-csv.driver "python3 scripts/l10n_merge.py csv %O %A %B"

codegen: $(CODEGEN_TARGETS) codegen-heart_language

$(CODEGEN_TARGETS): codegen-%:
	cd shared/$* && dart run build_runner build

# The other locales' ARBs, the generated Dart and the native permission strings,
# from scripts/translations.csv and the two intl_en.arb sources. Not committed
# (shared/heart_language/.gitignore), so a fresh checkout — and every CI job
# that analyzes, tests or builds the app — runs this first.
codegen-heart_language:
	cd shared/heart_language && dart run scripts/move.dart import

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

lint: format-check dates ui-imports lib/firebase_options.dart lib/firebase_options_prod.dart
	flutter analyze

# The app builds on material_ui and cupertino_ui. The framework's copies still
# exist, and a file importing one compiles fine — then its Theme.of, its
# MaterialApp and every widget it builds miss the app's, without a word. That is
# how go_router 18 took every page transition away (#188). The analyzer cannot
# tell the two apart; this can.
ui-imports:
	@if git ls-files -co --exclude-standard '*.dart' | xargs grep -n "package:flutter/\(material\|cupertino\)\.dart" ; then \
		echo "" ; \
		echo "import material_ui / cupertino_ui, not flutter/material.dart or flutter/cupertino.dart" ; \
		exit 1 ; \
	fi

# `DateFormat.yMMMd()` with no locale formats in en_US wherever it is called.
# It is invisible while you develop in English and it is why the History header
# read "SEPTEMBER 2026" on a Russian phone — and why one health card read an
# English date out to VoiceOver. Every call site passes a locale now; this is
# what keeps it that way. The analyzer has no rule for it.
dates:
	@if git ls-files '*.dart' | xargs grep -n 'DateFormat\.[a-zA-Z]*()' ; then \
		echo "" ; \
		echo "DateFormat without a locale — pass L.of(context).localeName or l.localeName" ; \
		exit 1 ; \
	fi

format-check:
	git ls-files -co --exclude-standard '*.dart' | xargs dart format --output=none --set-exit-if-changed

# format only files git knows about: `dart format .` would descend into
# build/ (including vendored SPM package checkouts) — it does not honor
# analyzer excludes and has no exclude flag
format:
	git ls-files -co --exclude-standard '*.dart' | xargs dart format

test: $(TEST_TARGETS) test-app test-scripts

# With REPORTS_DIR set (CI), each suite also writes a dart-test JSON report
# there for the Test Summary job to aggregate; locally nothing changes.
# $(call suite_test,<path or empty for the app>,<report name>)
define suite_test
$(if $(REPORTS_DIR),mkdir -p "$(REPORTS_DIR)" && )flutter test $(1) $(if $(REPORTS_DIR),--file-reporter="json:$(REPORTS_DIR)/$(2).json")
endef

test-heart_language: codegen-heart_language
	$(call suite_test,shared/heart_language,heart_language)

$(filter-out test-heart_language,$(TEST_TARGETS)): test-%: codegen-%
	$(call suite_test,shared/$*,$*)

test-app: codegen-app codegen-heart_language
	$(call suite_test,,app)

# the repo's own Python tooling (the translation merge driver)
test-scripts:
	cd scripts && python3 -m unittest discover -p 'test_*.py'

# just the screen×guideline accessibility matrix, for quick local runs
a11y: codegen-app
	flutter test test/a11y_test.dart

# app-only line coverage (lib/, generated code excluded) — the number
# test coverage tickets are measured against. `coverage/` is gitignored.
coverage: codegen-app
	flutter test --coverage
	@python3 scripts/coverage_report.py

# The two secrets buckets, one per AWS account. The fastlane match store lives
# under `secrets/fastlane/` in each, and which bucket you point at is what makes
# a profile dev's or prod's — they hold different distribution certificates.
DEV_BUCKET := 583168578067-ca-central-1-static
PROD_BUCKET := 922419543441-ca-central-1-static

# Create the App Store provisioning profiles for one environment, or reissue them.
#
#   make profiles ENV=dev            # create whatever is missing
#   make profiles ENV=prod FORCE=1   # reissue: after a capability change, or a
#                                    # profile bound to the wrong certificate
#
# The deploy lanes read the match store readonly, so this is the only thing that
# writes to it, and a bundle id with no profile there fails the deploy at `match`
# — see the `profiles` lane in ios/fastlane/Fastfile. Everything the lane needs
# comes from the environment's own bucket through its AWS profile; assembling
# those five variables by hand is how a nil bucket turns into
# "missing required option :name".
profiles:
	@case "$(ENV)" in dev|prod) ;; *) echo "ENV must be dev or prod"; exit 1 ;; esac
	@set -e; \
	case "$(ENV)" in prod) bucket=$(PROD_BUCKET) ;; *) bucket=$(DEV_BUCKET) ;; esac; \
	aws_profile=heart-$(ENV); \
	cd ios; \
	for key in AuthKey_CKGD3LH3ZH.p8 appstore_key.json; do \
		[ -f "fastlane/$$key" ] || \
			aws s3 cp "s3://$$bucket/secrets/appstore/$$key" "fastlane/$$key" --profile "$$aws_profile"; \
	done; \
	AWS_PROFILE=$$aws_profile \
	MATCH_S3_BUCKET=$$bucket \
	FASTLANE_SKIP_UPDATE_CHECK=1 \
	FASTLANE_HIDE_CHANGELOG=1 \
	SKIP_SLOW_FASTLANE_WARNING=1 \
	MATCH_PASSWORD=$$(aws s3 cp "s3://$$bucket/secrets/appstore/fastlane_passphrase.txt" - --profile "$$aws_profile") \
	APPSTORE_USERNAME=$$(jq -r .username fastlane/appstore_key.json) \
	fastlane profiles env:$(ENV) force:$(if $(FORCE),true,false)

# Disk leftovers: merged worktrees, stray agent simulators, stale DerivedData.
# Lists by default; APPLY=1 removes. See scripts/reclaim.sh.
reclaim:
	APPLY=$(APPLY) scripts/reclaim.sh
