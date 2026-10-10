"""Tests for the key-aware translation merge driver (scripts/l10n_merge.py)."""

import json
import unittest

from l10n_merge import merge, parse_arb, parse_csv, render_arb, render_csv


def arb(*entries: str) -> str:
    return "{\n" + ",\n".join("  " + e for e in entries) + "\n}\n"


A = '"a": "Alpha"'
A_META = '"@a": {"description": "first", "type": "text", "placeholders": {}}'
B = '"b": "Beta"'
B_META = '"@b": {\n    "description": "second",\n    "type": "text",\n    "placeholders": {\n      "n": {}\n    }\n  }'
C = '"c": "Gamma"'
C_META = '"@c": {"description": "third", "type": "text", "placeholders": {}}'


def merged_arb(base: str, ours: str, theirs: str):
    return merge(parse_arb(base), parse_arb(ours), parse_arb(theirs))


class ArbMerge(unittest.TestCase):
    def test_both_append_different_keys(self):
        base = arb(A, A_META)
        ours = arb(A, A_META, B, B_META)
        theirs = arb(A, A_META, C, C_META)

        result = merged_arb(base, ours, theirs)

        self.assertEqual(result.conflicts, [])
        text = render_arb(result.entries)
        # each side's additions follow the entry they were added after, ours first
        self.assertEqual(list(json.loads(text)), ["a", "@a", "b", "@b", "c", "@c"])
        # entries keep the bytes they were written as, multi-line metadata included
        self.assertIn(B_META, text)

    def test_same_key_added_identically_appears_once(self):
        base = arb(A, A_META)
        both = arb(A, A_META, B, B_META)

        result = merged_arb(base, both, both)

        self.assertEqual(result.conflicts, [])
        self.assertEqual(list(json.loads(render_arb(result.entries))), ["a", "@a", "b", "@b"])

    def test_one_side_changes_a_shared_key(self):
        base = arb(A, A_META, B, B_META)
        ours = arb(A, A_META, '"b": "Beta, reworded"', B_META)
        theirs = arb(A, A_META, B, B_META, C, C_META)

        result = merged_arb(base, ours, theirs)

        self.assertEqual(result.conflicts, [])
        self.assertEqual(json.loads(render_arb(result.entries))["b"], "Beta, reworded")

    def test_both_change_a_shared_key_differently_is_a_conflict(self):
        base = arb(A, A_META, B, B_META)
        ours = arb(A, A_META, '"b": "ours"', B_META)
        theirs = arb(A, A_META, '"b": "theirs"', B_META)

        result = merged_arb(base, ours, theirs)

        self.assertEqual(result.conflicts, ["b"])
        text = render_arb(result.entries)
        self.assertIn("<<<<<<< ours", text)
        self.assertIn('"b": "ours"', text)
        self.assertIn('"b": "theirs"', text)

    def test_deleted_on_one_side_untouched_on_the_other_is_deleted(self):
        base = arb(A, A_META, B, B_META)
        ours = arb(A, A_META)
        theirs = arb(A, A_META, B, B_META, C, C_META)

        result = merged_arb(base, ours, theirs)

        self.assertEqual(result.conflicts, [])
        self.assertEqual(list(json.loads(render_arb(result.entries))), ["a", "@a", "c", "@c"])

    def test_deleted_on_one_side_changed_on_the_other_is_a_conflict(self):
        base = arb(A, A_META, B, B_META)
        ours = arb(A, A_META)
        theirs = arb(A, A_META, '"b": "changed"', B_META)

        result = merged_arb(base, ours, theirs)

        self.assertEqual(result.conflicts, ["b"])

    def test_ours_only_key_lands_after_its_predecessor(self):
        base = arb(A, A_META, C, C_META)
        ours = arb(A, A_META, B, B_META, C, C_META)
        theirs = arb(A, A_META, C, C_META, '"d": "Delta"')

        result = merged_arb(base, ours, theirs)

        self.assertEqual(list(json.loads(render_arb(result.entries))), ["a", "@a", "b", "@b", "c", "@c", "d"])

    def test_unchanged_file_round_trips_byte_for_byte(self):
        source = arb(A, A_META, B, B_META)
        self.assertEqual(render_arb(parse_arb(source).entries_in_order()), source)


def rows(*lines: str) -> str:
    return "id,description,en,ru\n" + "".join(line + "\n" for line in lines)


class CsvMerge(unittest.TestCase):
    def test_both_append_rows(self):
        base = rows("a,first,Alpha,Альфа")
        ours = rows("a,first,Alpha,Альфа", 'b,"second, with a comma",Beta,Бета')
        theirs = rows("a,first,Alpha,Альфа", "c,third,Gamma,Гамма")

        result = merge(parse_csv(base), parse_csv(ours), parse_csv(theirs))

        self.assertEqual(result.conflicts, [])
        self.assertEqual(
            render_csv(result.entries),
            rows("a,first,Alpha,Альфа", 'b,"second, with a comma",Beta,Бета', "c,third,Gamma,Гамма"),
        )

    def test_a_row_spanning_lines_stays_one_entry(self):
        multi = 'b,second,"Beta\nover two lines",Бета'
        base = rows("a,first,Alpha,Альфа")
        ours = rows("a,first,Alpha,Альфа", multi)
        theirs = rows("a,first,Alpha,Альфа", "c,third,Gamma,Гамма")

        result = merge(parse_csv(base), parse_csv(ours), parse_csv(theirs))

        self.assertEqual(result.conflicts, [])
        self.assertIn(multi + "\n", render_csv(result.entries))
        self.assertEqual(len(result.entries), 4)

    def test_header_is_one_entry_and_theirs_wins_when_ours_kept_the_base(self):
        base = rows("a,first,Alpha,Альфа")
        ours = rows("a,first,Alpha,Альфа", "b,second,Beta,Бета")
        theirs = "id,description,en,ru,fr\n" + "a,first,Alpha,Альфа,Alpha\n"

        result = merge(parse_csv(base), parse_csv(ours), parse_csv(theirs))

        self.assertEqual(result.conflicts, [])
        self.assertTrue(render_csv(result.entries).startswith("id,description,en,ru,fr\n"))

    def test_same_row_changed_differently_is_a_conflict(self):
        base = rows("a,first,Alpha,Альфа")
        ours = rows("a,first,Alpha,Алфа")
        theirs = rows("a,first,Alpha!,Альфа")

        result = merge(parse_csv(base), parse_csv(ours), parse_csv(theirs))

        self.assertEqual(result.conflicts, ["a"])


if __name__ == "__main__":
    unittest.main()
