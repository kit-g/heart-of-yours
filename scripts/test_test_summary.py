"""The summary's JUnit reading (the Android native tests' Gradle reports) and
its adding up of a suite split over several jobs."""

import pathlib
import tempfile
import unittest

from test_summary import Suite, merge, parse_junit, render

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


if __name__ == "__main__":
    unittest.main()
