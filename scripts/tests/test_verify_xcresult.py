"""Negative acceptance cases for the evidence verifier; no simulator required."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "verify_xcresult.py"
SPEC = importlib.util.spec_from_file_location("verify_xcresult", SCRIPT)
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


def reports():
    summary = {
        "result": "Passed", "totalTestCount": 2, "passedTests": 2,
        "failedTests": 0, "skippedTests": 0, "expectedFailures": 0,
        "startTime": 100, "finishTime": 110, "testFailures": [],
    }
    targets = []
    for target, kind in (("AdonisTests", "Unit test bundle"), ("AdonisUITests", "UI test bundle")):
        targets.append({
            "nodeType": kind, "name": target, "result": "Passed", "children": [{
                "nodeType": "Test Suite", "name": "FlowTests", "result": "Passed", "children": [{
                    "nodeType": "Test Case", "name": "testSave()", "result": "Passed",
                    "nodeIdentifier": "FlowTests/testSave()",
                    "nodeIdentifierURL": f"test://com.apple.xcode/Adonis/{target}/FlowTests/testSave",
                }],
            }],
        })
    return summary, {"testNodes": targets, "devices": [{
        "deviceName": "iPhone", "platform": "iOS Simulator", "osVersion": "26.5",
    }]}


def first_case(tree):
    return tree["testNodes"][0]["children"][0]["children"][0]


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.summary, self.tree = reports()

    def test_success_checks_each_target_suite_and_method(self):
        report = verifier.verify(self.summary, self.tree, 2, [
            "AdonisTests", "AdonisUITests/FlowTests", "AdonisUITests/FlowTests/testSave()",
        ])
        self.assertEqual(report["testsByTarget"], {"AdonisTests": 1, "AdonisUITests": 1})
        self.assertEqual(report["requiredCoverage"]["AdonisUITests/FlowTests/testSave"], 1)

    def test_zero_tests_is_never_a_success(self):
        self.summary.update(totalTestCount=0, passedTests=0)
        self.tree["testNodes"] = []
        with self.assertRaisesRegex(verifier.VerificationError, "at least 1"):
            verifier.verify(self.summary, self.tree)

    def test_failed_skipped_expected_failure_or_unknown_is_rejected(self):
        for status in ("Failed", "Skipped", "Expected Failure", "unknown", None):
            with self.subTest(status=status):
                self.summary["result"] = status
                with self.assertRaisesRegex(verifier.VerificationError, "Bundle result"):
                    verifier.verify(self.summary, self.tree)

    def test_nonzero_failures_and_skips_are_rejected_even_with_passed_summary(self):
        for key in ("failedTests", "skippedTests", "expectedFailures"):
            with self.subTest(key=key):
                summary = dict(self.summary, **{key: 1})
                with self.assertRaisesRegex(verifier.VerificationError, key):
                    verifier.verify(summary, self.tree)

    def test_missing_and_mistyped_counts_fail_closed(self):
        for key in ("totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures"):
            for value in (None, "0", 0.0, False, -1):
                with self.subTest(key=key, value=value):
                    summary = dict(self.summary, **{key: value})
                    with self.assertRaisesRegex(verifier.VerificationError, "invalid test count"):
                        verifier.verify(summary, self.tree)

    def test_minimum_count_catches_partial_run(self):
        with self.assertRaisesRegex(verifier.VerificationError, "at least 234"):
            verifier.verify(self.summary, self.tree, 234)

    def test_invalid_minimum_cannot_disable_nonempty_gate(self):
        for minimum in (0, -1, True):
            with self.subTest(minimum=minimum), self.assertRaises(verifier.VerificationError):
                verifier.verify(self.summary, self.tree, minimum)

    def test_required_selectors_match_components_not_substrings(self):
        for selector in ("Adonis", "AdonisTests/Flow", "AdonisTests/FlowTests/testSav"):
            with self.subTest(selector=selector), self.assertRaisesRegex(
                verifier.VerificationError, "was not run successfully"
            ):
                verifier.verify(self.summary, self.tree, required=[selector])

    def test_missing_ui_target_cannot_be_replaced_by_unit_test_with_same_name(self):
        self.tree["testNodes"].pop()
        self.summary.update(totalTestCount=1, passedTests=1)
        with self.assertRaisesRegex(verifier.VerificationError, "AdonisUITests"):
            verifier.verify(self.summary, self.tree, required=["AdonisUITests/FlowTests/testSave"])

    def test_selector_typos_are_rejected(self):
        for selector in ("", "AdonisTests/", "/AdonisTests", "AdonisTests/*", " A/B", "A/B/C/D"):
            with self.subTest(selector=selector), self.assertRaisesRegex(
                verifier.VerificationError, "Invalid required selector"
            ):
                verifier.verify(self.summary, self.tree, required=[selector])

    def test_summary_and_case_tree_must_agree(self):
        self.tree["testNodes"].pop()
        with self.assertRaisesRegex(verifier.VerificationError, "tree contains 1"):
            verifier.verify(self.summary, self.tree)

    def test_nonpassed_case_or_retry_attempt_is_rejected(self):
        for status in ("Failed", "Skipped", "Expected Failure", "unknown", None):
            with self.subTest(status=status):
                tree = copy.deepcopy(self.tree)
                first_case(tree)["result"] = status
                with self.assertRaises(verifier.VerificationError):
                    verifier.verify(self.summary, tree)
        first_case(self.tree)["children"] = [{
            "nodeType": "Test Case Run", "name": "Attempt 1", "result": "Failed",
        }]
        with self.assertRaisesRegex(verifier.VerificationError, "Attempt 1: Failed"):
            verifier.verify(self.summary, self.tree)

    def test_duplicate_test_identity_is_rejected(self):
        self.tree["testNodes"].append(copy.deepcopy(self.tree["testNodes"][0]))
        with self.assertRaisesRegex(verifier.VerificationError, "Duplicate"):
            verifier.verify(self.summary, self.tree)

    def test_orphan_case_cannot_inherit_a_previous_sibling_target(self):
        orphan = copy.deepcopy(first_case(self.tree))
        self.tree["testNodes"].append(orphan)
        with self.assertRaisesRegex(verifier.VerificationError, "no target"):
            verifier.verify(self.summary, self.tree)

    def test_failed_parent_is_rejected_even_when_its_case_passes(self):
        self.tree["testNodes"][0]["result"] = "Failed"
        with self.assertRaisesRegex(verifier.VerificationError, "AdonisTests: Failed"):
            verifier.verify(self.summary, self.tree)

    def test_identifier_cannot_claim_a_different_target_from_its_url(self):
        first_case(self.tree)["nodeIdentifierURL"] = "test://com.apple.xcode/Adonis/Other/FlowTests/testSave"
        with self.assertRaisesRegex(verifier.VerificationError, "Conflicting"):
            verifier.verify(self.summary, self.tree)

    def test_missing_target_identifier_or_invalid_tree_is_rejected(self):
        for key in ("nodeIdentifier",):
            tree = copy.deepcopy(self.tree)
            first_case(tree).pop(key)
            with self.assertRaises(verifier.VerificationError):
                verifier.verify(self.summary, tree)
        for nodes in (None, {}, ["bad node"]):
            with self.subTest(nodes=nodes), self.assertRaises(verifier.VerificationError):
                verifier.verify(self.summary, {"testNodes": nodes})

    def test_completed_timestamps_are_required(self):
        for key, value in (("finishTime", None), ("startTime", 0), ("finishTime", 90),
                           ("finishTime", float("nan")), ("finishTime", float("inf"))):
            with self.subTest(key=key, value=value), self.assertRaisesRegex(
                verifier.VerificationError, "completed run not established"
            ):
                verifier.verify(dict(self.summary, **{key: value}), self.tree)

    def test_failure_details_are_not_ignored(self):
        for failures in (None, [{"failureText": "runner crashed"}]):
            with self.subTest(failures=failures), self.assertRaisesRegex(
                verifier.VerificationError, "failure details"
            ):
                verifier.verify(dict(self.summary, testFailures=failures), self.tree)


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="adonis-xcresult-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bundle = self.root / "test result.xcresult"
        self.bundle.mkdir()
        (self.bundle / "Info.plist").write_bytes(b"fixture")
        self.stdout, self.stderr = io.StringIO(), io.StringIO()

    def run_main(self, *extra):
        with contextlib.redirect_stdout(self.stdout), contextlib.redirect_stderr(self.stderr):
            return verifier.main([str(self.bundle), *extra])

    def test_completed_reports_write_traceable_evidence(self):
        output = self.root / "evidence.json"
        with patch.object(verifier, "read_report", side_effect=reports()):
            self.assertEqual(self.run_main("--output", str(output)), 0)
        report = json.loads(output.read_text())
        self.assertEqual(report["status"], "verified")
        self.assertEqual(report["bundle"], str(self.bundle.resolve()))
        self.assertEqual(len(report["sourceReportSHA256"]["tests"]), 64)
        self.assertIn("not current checkout", report["scope"])

    def test_existing_evidence_is_not_overwritten(self):
        output = self.root / "evidence.json"
        output.write_text("keep")
        with patch.object(verifier, "read_report", side_effect=reports()):
            self.assertEqual(self.run_main("--output", str(output)), 1)
        self.assertEqual(output.read_text(), "keep")
        self.assertEqual(self.stdout.getvalue(), "")

    def test_failed_verification_never_creates_success_evidence(self):
        output = self.root / "evidence.json"
        with patch.object(verifier, "read_report", side_effect=reports()):
            self.assertEqual(self.run_main("--minimum-tests", "3", "--output", str(output)), 1)
        self.assertFalse(output.exists())

    def test_input_bundle_is_read_only(self):
        with patch.object(verifier, "read_report") as reader:
            self.assertEqual(self.run_main("--output", str(self.bundle / "report.json")), 1)
            reader.assert_not_called()
        self.assertEqual([path.name for path in self.bundle.iterdir()], ["Info.plist"])

    def test_incomplete_bundle_is_rejected_before_xcresulttool(self):
        (self.bundle / "Info.plist").unlink()
        with patch.object(verifier, "read_report") as reader:
            self.assertEqual(self.run_main(), 1)
            reader.assert_not_called()

    def test_tool_arguments_preserve_paths_and_never_use_shell(self):
        response = subprocess.CompletedProcess([], 0, '{"result":"Passed"}')
        with patch.object(verifier.subprocess, "run", return_value=response) as run:
            self.assertEqual(verifier.read_report(self.bundle, "summary"), {"result": "Passed"})
        args, kwargs = run.call_args
        self.assertEqual(args[0][-2:], [str(self.bundle), "--compact"])
        self.assertNotIn("shell", kwargs)
        self.assertEqual(kwargs["timeout"], 60)

    def test_xcresulttool_errors_and_invalid_json_fail_closed(self):
        for error in (FileNotFoundError(), subprocess.TimeoutExpired("xcrun", 60),
                      subprocess.CalledProcessError(1, "xcrun")):
            with self.subTest(error=error), patch.object(verifier.subprocess, "run", side_effect=error):
                with self.assertRaises(verifier.VerificationError):
                    verifier.read_report(self.bundle, "summary")
        for payload in ("{invalid", "[]"):
            response = subprocess.CompletedProcess([], 0, payload)
            with self.subTest(payload=payload), patch.object(verifier.subprocess, "run", return_value=response):
                with self.assertRaises(verifier.VerificationError):
                    verifier.read_report(self.bundle, "summary")


if __name__ == "__main__":
    unittest.main()
