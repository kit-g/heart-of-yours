"""The summary's JUnit reading (the Android native tests' Gradle reports) and
its adding up of a suite split over several jobs."""

import json
import pathlib
import tempfile
import unittest

from test_summary import Suite, dart_suites, merge, parse_dart, parse_junit, render

_REPORT = """<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="me.heart.FunctionPlansTest" tests="4" skipped="1" failures="1" errors="1" time="0.2">
  <testcase name="plans a workout" classname="me.heart.FunctionPlansTest" time="0.1"/>
  <testcase name="skips this one" classname="me.heart.FunctionPlansTest" time="0"><skipped/></testcase>
  <testcase name="breaks" classname="me.heart.FunctionPlansTest" time="0.05"><failure message="no">boom</failure></testcase>
  <testcase name="throws" classname="me.heart.FunctionPlansTest" time="0.05"><error message="npe"/></testcase>
</testsuite>
"""


class ParseJunitTest(unittest.TestCase):
    def test_counts_each_outcome_and_names_the_broken_ones(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = pathlib.Path(tmp) / "android"
            directory.mkdir()
            (directory / "TEST-me.heart.FunctionPlansTest.xml").write_text(_REPORT)
            (directory / "TEST-me.heart.Other.xml").write_text(
                '<testsuite><testcase name="fine" classname="me.heart.Other" time="0.3"/></testsuite>'
            )

            suite = parse_junit(directory)

        self.assertEqual(suite.name, "android")
        self.assertEqual((suite.passed, suite.skipped, suite.failed), (2, 1, 2))
        self.assertEqual(
            suite.failures,
            ["me.heart.FunctionPlansTest breaks", "me.heart.FunctionPlansTest throws"],
        )
        self.assertEqual(suite.seconds, 0.5)
        self.assertIn("| `android` | ❌ | 2 | 2 | 1 | 0.5s |", render([suite]))

    def test_an_unreadable_report_is_left_out(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = pathlib.Path(tmp) / "android"
            directory.mkdir()
            (directory / "TEST-broken.xml").write_text("<testsuite>")

            suite = parse_junit(directory)

        self.assertEqual(suite.total, 0)


class MergeTest(unittest.TestCase):
    def test_shards_add_up_and_take_the_slowest_time(self):
        suite = merge(
            "app",
            [
                Suite(name="app", passed=10, skipped=2, seconds=120.5),
                Suite(name="app", passed=7, failed=1, seconds=140.0, failures=["breaks"]),
            ],
        )

        self.assertEqual((suite.passed, suite.failed, suite.skipped), (17, 1, 2))
        self.assertEqual(suite.seconds, 140.0)
        self.assertEqual(suite.failures, ["breaks"])
        self.assertIn("| `app` | ❌ | 17 | 1 | 2 | 140.0s |", render([suite]))



def _report(directory: pathlib.Path, name: str, *events: dict) -> pathlib.Path:
    path = directory / name
    path.write_text("\n".join(json.dumps(event) for event in events))
    return path


def _passing(test_id: int, name: str) -> list[dict]:
    return [
        {"type": "testStart", "test": {"id": test_id, "name": name}},
        {"type": "testDone", "testID": test_id, "result": "success", "hidden": False},
    ]


class ShardedReportsTest(unittest.TestCase):
    def test_a_shard_with_no_report_fails_the_row_by_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = pathlib.Path(tmp)
            paths = [
                _report(directory, f"app.{k}-of-3.json", *_passing(1, "fine"))
                for k in (1, 3)
            ]
            (suite,) = dart_suites(paths)

        self.assertEqual(suite.name, "app")
        self.assertFalse(suite.ok)
        self.assertEqual(suite.failures, ["shard 2 of 3 left no report"])

    def test_only_the_shard_suffix_groups_reports(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = pathlib.Path(tmp)
            paths = [
                _report(directory, "app.json", *_passing(1, "whole")),
                _report(directory, "app.1-of-1.json", *_passing(1, "shard")),
                _report(directory, "heart.v2.json", *_passing(1, "dotted")),
            ]
            suites = dart_suites(paths)

        self.assertEqual(sorted((s.name, s.passed) for s in suites), [("app", 1), ("app", 1), ("heart.v2", 1)])


class ParseDartTest(unittest.TestCase):
    def test_a_file_that_fails_to_load_is_a_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _report(
                pathlib.Path(tmp),
                "app.json",
                {"type": "testStart", "test": {"id": 1, "name": "loading test/fine_test.dart"}},
                {"type": "testDone", "testID": 1, "result": "success", "hidden": True},
                {"type": "testStart", "test": {"id": 2, "name": "loading test/broken_test.dart"}},
                {"type": "testDone", "testID": 2, "result": "error", "hidden": False},
            )
            suite = parse_dart(path)

        self.assertEqual((suite.passed, suite.failed), (0, 1))
        self.assertEqual(suite.failures, ["loading test/broken_test.dart"])


if __name__ == "__main__":
    unittest.main()
