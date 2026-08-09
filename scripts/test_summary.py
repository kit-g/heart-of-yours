#!/usr/bin/env python3
"""Turn dart-test JSON reports into one markdown table for the GitHub job summary.

Every test job in `.github/workflows/unit-tests.yml` runs its make target with
REPORTS_DIR set, which makes `flutter test` drop a JSON report into
`test-reports/`; each job uploads its report as an artifact and the final
"Test Summary" job downloads them all and runs this to render a single view.

Input: `dart test --file-reporter=json` output — newline-delimited events.
Counted from `testDone` events, ignoring the synthetic "loading …" suites the
reporter emits per file.

Usage:  test_summary.py <report-dir>

Writes markdown to stdout. Exit status is always 0 — this reports on a run, it
does not judge it; the test steps themselves decide whether the build fails.

Adapted from heart-api's scripts/test_summary.py (its TAP/coverage inputs have
no equivalent here).
"""

from __future__ import annotations

import json
import pathlib
import sys
from dataclasses import dataclass, field


@dataclass
class Suite:
    name: str
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    seconds: float = 0.0
    failures: list[str] = field(default_factory=list)

    @property
    def total(self) -> int:
        return self.passed + self.failed + self.skipped

    @property
    def ok(self) -> bool:
        return self.failed == 0 and self.total > 0


def parse_dart(path: pathlib.Path) -> Suite:
    """Count testDone events from the Dart JSON reporter's event stream."""
    suite = Suite(name=path.stem)
    names: dict[int, str] = {}

    for line in path.read_text().splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        match event.get("type"):
            case "testStart":
                test = event.get("test", {})
                names[test.get("id")] = test.get("name", "")
            case "testDone":
                # The reporter emits a synthetic "loading <file>" test per suite;
                # counting those would inflate every total by the file count.
                name = names.get(event.get("testID"), "")
                if event.get("hidden") or name.startswith("loading "):
                    continue
                match (event.get("result"), event.get("skipped")):
                    case (_, True):
                        suite.skipped += 1
                    case ("success", _):
                        suite.passed += 1
                    case _:
                        suite.failed += 1
                        suite.failures.append(name)
            case "done":
                suite.seconds = round(event.get("time", 0) / 1000, 1)

    return suite


def render(suites: list[Suite]) -> str:
    out: list[str] = ["## Test results", ""]

    if not suites:
        return "\n".join(out + ["No test reports were produced."])

    out += [
        "| Suite | Result | Passed | Failed | Skipped | Time |",
        "|---|---|--:|--:|--:|--:|",
    ]
    for suite in sorted(suites, key=lambda s: s.name):
        icon = "✅" if suite.ok else "❌"
        time = f"{suite.seconds}s" if suite.seconds else "—"
        out.append(
            f"| `{suite.name}` | {icon} | {suite.passed} | {suite.failed} "
            f"| {suite.skipped or '—'} | {time} |"
        )

    total_passed = sum(s.passed for s in suites)
    total_failed = sum(s.failed for s in suites)
    total_skipped = sum(s.skipped for s in suites)
    out.append(
        f"| **Total** | {'✅' if total_failed == 0 else '❌'} | **{total_passed}** "
        f"| **{total_failed}** | **{total_skipped or '—'}** | |"
    )
    out.append("")

    # Name what broke, so the summary is actionable without opening the logs.
    if failing := [s for s in suites if s.failures]:
        out += ["### Failures", ""]
        for suite in failing:
            out.append(f"**`{suite.name}`**")
            out += [f"- {name}" for name in suite.failures[:25]]
            if len(suite.failures) > 25:
                out.append(f"- …and {len(suite.failures) - 25} more")
            out.append("")

    return "\n".join(out)


def main() -> int:
    reports = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "test-reports")
    suites = [parse_dart(path) for path in sorted(reports.rglob("*.json"))]
    print(render(suites))
    return 0


if __name__ == "__main__":
    sys.exit(main())
