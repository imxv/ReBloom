#!/usr/bin/env python3
"""Verify a completed XCTest bundle without building or touching a simulator."""

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from urllib.parse import unquote, urlsplit


class VerificationError(Exception):
    """The bundle cannot establish a successful regression."""


def read_report(bundle, kind):
    try:
        result = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", kind,
             "--path", str(bundle), "--compact"],
            check=True, capture_output=True, text=True, timeout=60,
        )
        value = json.loads(result.stdout)
    except subprocess.CalledProcessError as error:
        raise VerificationError(
            f"xcresulttool could not read {kind}; bundle may be incomplete or incompatible."
        ) from error
    except (OSError, subprocess.TimeoutExpired, ValueError) as error:
        raise VerificationError(f"Could not read {kind}: {error}") from error
    if not isinstance(value, dict):
        raise VerificationError(f"{kind} must be a JSON object.")
    return value


def count(summary, key):
    value = summary.get(key)
    if type(value) is not int or value < 0:
        raise VerificationError(f"Missing or invalid test count: {key}.")
    return value


def normalize_selector(value):
    # XCTest method names may be displayed with trailing parentheses.
    value = value.removesuffix("()")
    parts = value.split("/")
    if not 1 <= len(parts) <= 3 or any(
        not part or part.strip() != part or part in (".", "..")
        or any(character in part for character in "*?[]\\\n\r\t")
        for part in parts
    ):
        raise VerificationError(f"Invalid required selector: {value!r}.")
    return value


def collect_cases(tests):
    cases = {}
    problems = []

    def visit(nodes, target=None):
        if not isinstance(nodes, list):
            raise VerificationError("Invalid test tree: children must be an array.")
        for node in nodes:
            if not isinstance(node, dict):
                raise VerificationError("Invalid test tree node.")
            kind = node.get("nodeType")
            node_target = target
            if kind in ("Unit test bundle", "UI test bundle"):
                node_target = node.get("name")
            if kind in ("Test Case", "Test Case Run") or (
                kind in ("Test Plan", "Unit test bundle", "UI test bundle", "Test Suite", "Repetition")
                and "result" in node
            ):
                if node.get("result") != "Passed":
                    problems.append(f"{node.get('name', kind)}: {node.get('result', 'missing result')}")
            if kind == "Test Case":
                identifier = node.get("nodeIdentifier")
                if not isinstance(node_target, str) or not node_target or not isinstance(identifier, str):
                    raise VerificationError("Test case has no target or identifier.")
                selector = normalize_selector(f"{node_target}/{identifier}")
                if selector in cases:
                    raise VerificationError(f"Duplicate test identity is not supported: {selector}.")
                # Cross-check the independently reported target-qualified URL when present.
                if "nodeIdentifierURL" in node:
                    if not isinstance(node["nodeIdentifierURL"], str):
                        raise VerificationError(f"Invalid test identity URL: {selector}.")
                    url = urlsplit(node["nodeIdentifierURL"])
                    url_path = unquote(url.path).strip("/")
                    if url.scheme != "test" or not url_path.endswith("/" + selector):
                        raise VerificationError(f"Conflicting test identity: {selector}.")
                cases[selector] = node.get("result")
            visit(node.get("children", []), node_target)

    visit(tests.get("testNodes"))
    return cases, problems


def verify(summary, tests, minimum_tests=1, required=()):
    if type(minimum_tests) is not int or minimum_tests < 1:
        raise VerificationError("minimum_tests must be a positive integer.")
    required = sorted(set(normalize_selector(item) for item in required))
    counts = {key: count(summary, key) for key in (
        "totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures"
    )}
    problems = []
    if summary.get("result") != "Passed":
        problems.append(f"Bundle result is {summary.get('result', 'missing')}.")
    for key in ("failedTests", "skippedTests", "expectedFailures"):
        if counts[key] != 0:
            problems.append(f"{key} must be zero, observed {counts[key]}.")
    if counts["totalTestCount"] < minimum_tests:
        problems.append(f"Expected at least {minimum_tests} tests, observed {counts['totalTestCount']}.")
    if counts["passedTests"] != counts["totalTestCount"]:
        problems.append("Not every test is reported as passed.")
    if not isinstance(summary.get("testFailures"), list) or summary["testFailures"]:
        problems.append("Test failure details are present or missing from the summary.")
    start, finish = summary.get("startTime"), summary.get("finishTime")
    if not all(type(value) in (int, float) and math.isfinite(value) and value > 0
               for value in (start, finish)) or finish < start:
        problems.append("Missing or invalid start/finish times; completed run not established.")
    cases, case_problems = collect_cases(tests)
    problems.extend(case_problems)
    if len(cases) != counts["totalTestCount"]:
        problems.append(f"Test tree contains {len(cases)} cases but summary declares {counts['totalTestCount']}.")
    coverage = {}
    for selector in required:
        matched = [name for name, result in cases.items()
                   if (name == selector or name.startswith(selector + "/")) and result == "Passed"]
        coverage[selector] = len(matched)
        if not matched:
            problems.append(f"Required test/target/suite was not run successfully: {selector}.")
    if problems:
        raise VerificationError("\n".join(problems))
    return {
        "status": "verified",
        "counts": counts,
        "startTime": start,
        "finishTime": finish,
        "minimumTests": minimum_tests,
        "requiredCoverage": coverage,
        "testsByTarget": dict(sorted(Counter(name.split('/')[0] for name in cases).items())),
        "passedTestIdentifiers": sorted(cases),
    }


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def positive_integer(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path, help="Explicit .xcresult path; never selects the newest run")
    parser.add_argument("--minimum-tests", type=positive_integer, default=1)
    parser.add_argument("--require", action="append", default=[], metavar="TARGET[/SUITE[/TEST]]")
    parser.add_argument("--output", type=Path, help="Create a JSON evidence file; refuses to overwrite")
    args = parser.parse_args(argv)
    try:
        bundle = args.bundle.resolve()
        if bundle.suffix != ".xcresult" or not bundle.is_dir() or not (bundle / "Info.plist").is_file():
            raise VerificationError("Expected a completed .xcresult directory containing Info.plist.")
        if args.output and args.output.resolve().is_relative_to(bundle):
            raise VerificationError("Evidence output must be outside the input result bundle.")
        summary = read_report(bundle, "summary")
        tests = read_report(bundle, "tests")
        report = verify(summary, tests, args.minimum_tests, args.require)
        devices = tests.get("devices")
        if not isinstance(devices, list) or not devices or any(not isinstance(device, dict) for device in devices):
            raise VerificationError("Missing or invalid test device metadata.")
        report.update({
            "schemaVersion": "adonis-xcresult-verification-v1",
            "verifiedAt": datetime.now(timezone.utc).isoformat(),
            "bundle": str(bundle),
            "sourceReportSHA256": {"summary": fingerprint(summary), "tests": fingerprint(tests)},
            "devices": [{key: device[key] for key in ("deviceName", "platform", "osVersion") if key in device}
                        for device in devices],
            "scope": "Recorded XCTest execution only; not current checkout, screenshot review, real provider, or physical-device acceptance.",
        })
        encoded = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            with args.output.open("x", encoding="utf-8") as output:
                output.write(encoded)
        print(encoded, end="")
        return 0
    except (VerificationError, OSError) as error:
        print(f"XCResult verification failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
