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
#   make wear        the Wear OS app (#250), dev debug; wear-install puts it on
#                    DEVICE=<adb serial>, wear-test runs its unit tests,
#                    wear-pages its Compose tests on DEVICE

# Packages with a test suite in the CI matrix.
PACKAGES := heart_api heart_db heart_state heart_charts heart_language heart_health
# Packages whose tests need generated code (mocks) first. heart_charts has
# none, and heart_language's is the translation import (codegen-heart_language).
CODEGEN_PACKAGES := heart_api heart_db heart_state heart_health

TEST_TARGETS := $(addprefix test-,$(PACKAGES))

.PHONY: bootstrap deps hooks codegen codegen-heart_language lint format format-check test test-app \
        test-scripts test-sealbox profiles reclaim wear wear-install wear-test wear-pages $(TEST_TARGETS)

bootstrap: hooks deps codegen
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

# Everything at once: the translation import, then one build_runner over the
# whole workspace (every package and the app). One process resolves the shared
# dependencies once; a build per package took ~30s each, ~3 minutes in all.
# It is the only codegen target on purpose: a workspace build and a one-package
# build keep different plans in the same cache, so alternating them rebuilds
# from scratch each time (deleting the mocks meanwhile).
codegen: codegen-heart_language
	dart run build_runner build --workspace

# The other locales' ARBs, the generated Dart and the native permission strings,
# from scripts/translations.csv and the two intl_en.arb sources. Not committed
# (shared/heart_language/.gitignore), so a fresh checkout — and every CI job
# that analyzes, tests or builds the app — runs this first.
codegen-heart_language:
	cd shared/heart_language && dart run scripts/move.dart import

# `flutter analyze` must resolve the gitignored Firebase options; on machines
# without Firebase credentials (CI), stub them. `flutterfire configure`
# produces the real ones (see README) — when present, these are no-ops.
# Note: analysis also needs generated mocks — CI runs `make codegen`
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

lint: format-check dates ui-imports layers buttons lib/firebase_options.dart lib/firebase_options_prod.dart
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

# a button's height is the house's: QuietButton and PrimaryButton answer taps
# over a full target without being drawn tall (docs/style.md)
buttons:
	@if git ls-files -co --exclude-standard 'lib/*.dart' | grep -v '^lib/core/theme/' | xargs grep -nE "minimumSize:" ; then \
		echo "" ; \
		echo "no hand-set button sizes: QuietButton, or PrimaryButton with a hitHeight (docs/style.md)" ; \
		exit 1 ; \
	fi

# The packages are layers, and a dependency only points down: the app on
# everything; heart_api on heart_models and the HTTP stack; heart_state and the
# other shared packages on heart_models, never on HTTP. HTTP types stop at
# heart_api: a transport failure reaches the state layer as a heart_models type
# (ServerRefusal, AccountDeleted), never as a NetworkException (#681). One
# import across a boundary compiles fine and is the start of a tangle, and the
# analyzer has no rule for it, so this checks every import and pubspec.
LOWER := heart_state heart_db heart_charts heart_health heart_language sealbox
layers:
	@bad=0 ; \
	for p in $(LOWER) ; do \
		if git ls-files -co --exclude-standard "shared/$$p/*.dart" | xargs grep -nE "package:(http|network_utils|heart_api)/" ; then bad=1 ; fi ; \
		if grep -nE "^[[:space:]]+(http|network_utils|heart_api):" shared/$$p/pubspec.yaml ; then echo "shared/$$p/pubspec.yaml" ; bad=1 ; fi ; \
		if git ls-files -co --exclude-standard "shared/$$p/*.dart" | xargs grep -nE "package:heart/" ; then bad=1 ; fi ; \
	done ; \
	if git ls-files -co --exclude-standard "shared/heart_api/*.dart" | xargs grep -nE "package:(heart_state|heart_db|heart)/" ; then bad=1 ; fi ; \
	if [ $$bad = 1 ] ; then \
		echo "" ; \
		echo "an import across layers: HTTP stays in heart_api, shared packages never import the app or heart_api" ; \
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

test: $(TEST_TARGETS) test-app test-scripts test-sealbox

# With REPORTS_DIR set (CI), each suite also writes a dart-test JSON report
# there for the Test Summary job to aggregate; locally nothing changes.
# $(call suite_test,<path or empty for the app>,<report name>)
define suite_test
$(if $(REPORTS_DIR),mkdir -p "$(REPORTS_DIR)" && )flutter test $(1) $(if $(REPORTS_DIR),--file-reporter="json:$(REPORTS_DIR)/$(2).json")
endef

test-heart_language: codegen-heart_language
	$(call suite_test,shared/heart_language,heart_language)

$(addprefix test-,$(CODEGEN_PACKAGES)): test-%: codegen
	$(call suite_test,shared/$*,$*)

test-heart_charts:
	$(call suite_test,shared/heart_charts,heart_charts)

# The app suite runs as an explicit, sorted file list: left to find them itself,
# flutter test takes files in directory order, and the heavy a11y_<n> shards
# could start last. SHARD=<k>/<n> runs every n-th file from the k-th (1-based),
# so CI can spread the suite over n jobs that each compile only their own
# files; each shard's report is app.<k>-of-<n>, and the summary adds them up.
# A SHARD that selects nothing is an error: an empty list would make a bare
# `flutter test`, which runs the whole suite under the shard's name.
SHARD ?= 1/1
APP_TEST_FILES = $(shell find test -name '*_test.dart' | LC_ALL=C sort | \
	awk -v k=$(word 1,$(subst /, ,$(SHARD))) -v n=$(word 2,$(subst /, ,$(SHARD))) \
	'n > 0 && k >= 1 && k <= n && (NR - 1) % n == k - 1')

test-app: codegen
	$(if $(APP_TEST_FILES),,$(error SHARD=$(SHARD) selects no test files: it is <k>/<n>, k from 1 to n))
	$(call suite_test,$(APP_TEST_FILES),app$(if $(filter-out 1/1,$(SHARD)),.$(subst /,-of-,$(SHARD))))

# The encryption package (#565): its Rust crate, then its Dart API over the
# library the build hook compiles. dart test from inside the package, since a
# test run from the root builds native code only for what the app depends on.
# Needs Rust (rustup): rust-toolchain.toml pins the toolchain, and the hook adds
# each target as it builds for it. REPORTS_DIR is made absolute: the recipe cd's.
test-sealbox:
	cd shared/sealbox/rust && cargo fmt --check && cargo clippy --all-targets --locked -- -D warnings && cargo test --locked
	cd shared/sealbox && $(if $(REPORTS_DIR),mkdir -p "$(abspath $(REPORTS_DIR))" && )dart test $(if $(REPORTS_DIR),--file-reporter="json:$(abspath $(REPORTS_DIR))/sealbox.json")

# the repo's own Python tooling (the translation merge driver)
test-scripts:
	cd scripts && python3 -m unittest discover -p 'test_*.py'

# just the screen×guideline accessibility matrix, for quick local runs
a11y: codegen
	flutter test $(wildcard test/a11y_*_test.dart)

# app-only line coverage (lib/, generated code excluded) — the number
# test coverage tickets are measured against. `coverage/` is gitignored.
coverage: codegen
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

# The Wear OS app (#250) is its own Gradle build under android/wear, native
# Compose with no Flutter in it. AGP wants JDK 17+, and its lint JDK 21: take
# JAVA_HOME when set, else Android Studio's bundled JDK.
WEAR_JAVA_HOME := $(or $(JAVA_HOME),/Applications/Android Studio.app/Contents/jbr/Contents/Home)
WEAR_GRADLE := cd android/wear && JAVA_HOME="$(WEAR_JAVA_HOME)" ANDROID_HOME="$(or $(ANDROID_HOME),$(HOME)/Library/Android/sdk)" ./gradlew -q

wear:
	$(WEAR_GRADLE) assembleDevDebug

wear-install: wear
	@[ -n "$(DEVICE)" ] || { echo "DEVICE=<adb serial> (adb devices)"; exit 1; }
	adb -s $(DEVICE) install -r android/wear/build/outputs/apk/dev/debug/heart-wear-dev-debug.apk

wear-test:
	$(WEAR_GRADLE) testDevDebugUnitTest

# The pages, as Compose tests on a Wear OS emulator (DEVICE=<adb serial>)
wear-pages:
	@[ -n "$(DEVICE)" ] || { echo "DEVICE=<adb serial> (adb devices)"; exit 1; }
	ANDROID_SERIAL=$(DEVICE) $(WEAR_GRADLE) connectedDevDebugAndroidTest

# Disk leftovers: merged worktrees, stray agent simulators, stale DerivedData.
# Lists by default; APPLY=1 removes; WORKTREE=<branch> touches that merged
# worktree and its branch only. See scripts/reclaim.sh.
reclaim:
	APPLY=$(APPLY) WORKTREE=$(WORKTREE) scripts/reclaim.sh
