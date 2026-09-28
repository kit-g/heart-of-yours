#!/usr/bin/env python3
"""Summarizes coverage/lcov.info for lib/, excluding generated code.

Run `flutter test --coverage` first (or `make coverage`, which does both).

Usage: python3 scripts/coverage_report.py [path/prefix ...]

With no arguments, prints the overall lib/ total. With arguments, also
prints per-file coverage for any lib/ file whose path contains one of the
given substrings (handy for checking one file's number).

Matches flutter/lcov convention: only files `coverage/lcov.info` actually
instrumented (i.e. reached by some test's import graph) count toward the
total. A `lib/` file no test ever imports — `main.dart`, a platform-specific
stub behind a conditional import — has no DA lines to instrument and is
absent from lcov.info entirely, the same way it would be from `genhtml`'s
summary.
"""

import re
import sys

EXCLUDE_PATTERNS = [
    re.compile(r"\.g\.dart$"),
    re.compile(r"\.mocks\.dart$"),
    re.compile(r"/l10n/"),
    re.compile(r"generated_plugin_registrant\.dart$"),
    re.compile(r"firebase_options"),
]


def is_excluded(path):
    return any(p.search(path) for p in EXCLUDE_PATTERNS)


def parse_lcov(lcov_path):
    files = {}
    current = None
    with open(lcov_path) as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("SF:"):
                current = line[3:]
                files[current] = {}
            elif line.startswith("DA:") and current is not None:
                parts = line[3:].split(",")
                lineno = int(parts[0])
                hits = int(parts[1])
                # a later DA for the same line (rare) wins with the max hit count
                files[current][lineno] = max(hits, files[current].get(lineno, 0))
            elif line == "end_of_record":
                current = None
    return files


def main():
    files = parse_lcov("coverage/lcov.info")
    filters = sys.argv[1:]

    total_lines = 0
    total_covered = 0
    rows = []
    for path, lines in sorted(files.items()):
        if not path.startswith("lib/") or is_excluded(path):
            continue
        n = len(lines)
        c = sum(1 for h in lines.values() if h > 0)
        total_lines += n
        total_covered += c
        rows.append((path, n, c))

    if filters:
        for path, n, c in rows:
            if any(f in path for f in filters):
                pct = 100 * c / n if n else 0
                print(f"{pct:6.1f}%  {c:5}/{n:<5}  {path}")

    pct = 100 * total_covered / total_lines if total_lines else 0
    print(f"\nTOTAL lib/: {pct:.2f}% ({total_covered}/{total_lines} lines, {len(rows)} files)")


if __name__ == "__main__":
    main()
