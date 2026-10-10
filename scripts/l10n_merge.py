#!/usr/bin/env python3
"""Key-aware git merge driver for the translation sources.

Two branches that each add strings touch the same tail of `intl_en.arb` and
`translations.csv`, and git's line merge calls that a conflict every time,
however unrelated the keys. This merges by key instead: an entry is an ARB
key (or its `@key` metadata) or a CSV row by `id`, and the three-way merge
is done over entries, each kept as the bytes it was written as.

Rules, per key, against the merge base:
- changed on one side only: that side's entry;
- added on one side only: added, after the entry that preceded it there;
- added on both sides, identically, or changed identically: once;
- deleted on one side and untouched on the other: deleted;
- changed differently on both sides, or deleted on one and changed on the
  other: a conflict, written out between the usual markers for a human.

Registered by `make hooks` (`merge.l10n-arb.driver`, `merge.l10n-csv.driver`)
and wired to the files in `.gitattributes`. Git calls it as

    l10n_merge.py (arb|csv) <base> <ours> <theirs>

with the result to be written over <ours>; exit 0 for a clean merge, 1 for a
conflict. The files the import derives from these are not committed, so they
have nothing to merge: `make codegen-heart_language` rebuilds them.
"""

from __future__ import annotations

import csv
import io
import json
import sys
from dataclasses import dataclass

HEADER = "\0header"


@dataclass(frozen=True)
class Document:
    """Entries by key, in file order, each as its original text."""

    order: list[str]
    text: dict[str, str]

    def entries_in_order(self) -> list[str]:
        return [self.text[key] for key in self.order]


# --- ARB -----------------------------------------------------------------


def parse_arb(source: str) -> Document:
    """Splits a one-object ARB into its top-level entries.

    The value of each key is located with the JSON decoder, so an entry's
    text is exactly `"key": <value>` as written, formatting and all; the
    indentation before the key is dropped and restored on output.
    """
    decoder = json.JSONDecoder()
    order: list[str] = []
    text: dict[str, str] = {}
    position = source.index("{") + 1
    while True:
        position = _skip(source, position, " \t\r\n,")
        if source[position] == "}":
            break
        if source[position] != '"':
            raise ValueError(f"expected a key at offset {position}")
        key, position_after_key = decoder.raw_decode(source, position)
        colon = _skip(source, position_after_key, " \t\r\n")
        if source[colon] != ":":
            raise ValueError(f"expected ':' after {key!r}")
        value_start = _skip(source, colon + 1, " \t\r\n")
        _, end = decoder.raw_decode(source, value_start)
        if key in text:
            raise ValueError(f"duplicate key {key!r}")
        order.append(key)
        text[key] = source[position:end]
        position = end
    return Document(order, text)


def render_arb(entries: list[str]) -> str:
    return "{\n" + ",\n".join("  " + entry for entry in entries) + "\n}\n"


def _skip(source: str, position: int, characters: str) -> int:
    while position < len(source) and source[position] in characters:
        position += 1
    return position


# --- CSV -----------------------------------------------------------------


def parse_csv(source: str) -> Document:
    """Splits the CSV into rows by `id`, each as its original lines.

    Rows can span lines (quoted fields hold newlines), so the reader's line
    count after each row says where that row's text ends. The header row is
    kept under its own key.
    """
    lines = source.splitlines(keepends=True)
    reader = csv.reader(lines)
    order: list[str] = []
    text: dict[str, str] = {}
    consumed = 0
    for index, row in enumerate(reader):
        raw = "".join(lines[consumed : reader.line_num])
        consumed = reader.line_num
        if not row or not any(cell.strip() for cell in row):
            continue
        key = HEADER if index == 0 else row[0]
        if key in text:
            raise ValueError(f"duplicate row id {key!r}")
        order.append(key)
        text[key] = raw if raw.endswith("\n") else raw + "\n"
    return Document(order, text)


def render_csv(entries: list[str]) -> str:
    return "".join(entries)


# --- the merge -----------------------------------------------------------


@dataclass(frozen=True)
class Merged:
    entries: list[str]
    conflicts: list[str]


def merge(base: Document, ours: Document, theirs: Document) -> Merged:
    """Three-way merge over entries. Theirs' order is the spine; what only
    ours has goes in after its predecessor in ours, or at the end."""
    conflicts: list[str] = []
    resolved: dict[str, str | None] = {}

    for key in dict.fromkeys([*theirs.order, *ours.order, *base.order]):
        in_base, in_ours, in_theirs = base.text.get(key), ours.text.get(key), theirs.text.get(key)
        if in_ours == in_theirs:
            resolved[key] = in_ours
        elif in_ours == in_base:
            resolved[key] = in_theirs
        elif in_theirs == in_base:
            resolved[key] = in_ours
        else:
            conflicts.append(key)
            resolved[key] = _conflict(in_ours, in_theirs)

    order = [key for key in theirs.order if resolved.get(key) is not None]
    for position, key in enumerate(ours.order):
        if key in order or resolved.get(key) is None:
            continue
        previous = next((k for k in reversed(ours.order[:position]) if k in order), None)
        order.insert(order.index(previous) + 1 if previous is not None else len(order), key)

    return Merged([resolved[key] for key in order], conflicts)  # type: ignore[misc]


def _conflict(ours: str | None, theirs: str | None) -> str:
    return "\n".join(
        [
            "<<<<<<< ours",
            *([ours.rstrip("\n")] if ours is not None else []),
            "=======",
            *([theirs.rstrip("\n")] if theirs is not None else []),
            ">>>>>>> theirs",
        ]
    ) + "\n"


FORMATS = {
    "arb": (parse_arb, render_arb),
    "csv": (parse_csv, render_csv),
}


def main(argv: list[str]) -> int:
    if len(argv) != 5 or argv[1] not in FORMATS:
        print(__doc__, file=sys.stderr)
        return 2
    kind, base_path, ours_path, theirs_path = argv[1:]
    parse, render = FORMATS[kind]
    with open(base_path, encoding="utf-8", newline="") as f:
        base = parse(f.read())
    with open(ours_path, encoding="utf-8", newline="") as f:
        ours = parse(f.read())
    with open(theirs_path, encoding="utf-8", newline="") as f:
        theirs = parse(f.read())
    result = merge(base, ours, theirs)
    with open(ours_path, "w", encoding="utf-8", newline="") as f:
        f.write(render(result.entries))
    for key in result.conflicts:
        print(f"l10n merge: conflict on {key!r} in {ours_path}", file=sys.stderr)
    return 1 if result.conflicts else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
