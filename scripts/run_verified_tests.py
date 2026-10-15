#!/usr/bin/env python3
"""Run xcodebuild tests with an isolated result path and verify that exact bundle."""

import argparse
from pathlib import Path
import subprocess
import sys
import uuid

from verify_xcresult import VerificationError, main as verify_result, normalize_selector, positive_integer


def required_selectors(arguments, explicit):
    required = list(explicit)
    for index, argument in enumerate(arguments):
        if argument.startswith("-only-testing:"):
            required.append(argument.removeprefix("-only-testing:"))
        elif argument == "-only-testing":
            if index + 1 == len(arguments) or arguments[index + 1].startswith("-"):
                raise VerificationError("-only-testing requires a target, suite, or method selector.")
            required.append(arguments[index + 1])
    return sorted(set(normalize_selector(selector) for selector in required))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--minimum-tests", type=positive_integer, default=1)
    parser.add_argument("--require", action="append", default=[])
    parser.add_argument("--result-root", type=Path, default=Path(".artifacts/verified-tests"))
    parser.add_argument("xcode_arguments", nargs=argparse.REMAINDER, help="-- followed by xcodebuild test arguments")
    args = parser.parse_args(argv)
    arguments = args.xcode_arguments
    if arguments[:1] == ["--"]:
        arguments = arguments[1:]
    try:
        if not any(action in arguments for action in ("test", "test-without-building")):
            raise VerificationError("Provide an xcodebuild test or test-without-building action after --.")
        if any(argument.startswith("-resultBundlePath") for argument in arguments):
            raise VerificationError("The runner owns -resultBundlePath; use --result-root instead.")
        required = required_selectors(arguments, args.require)
        run_directory = args.result_root.resolve() / uuid.uuid4().hex
        run_directory.mkdir(parents=True, exist_ok=False)
        bundle = run_directory / "tests.xcresult"
        evidence = run_directory / "verification.json"
        print(f"Test result: {bundle}", flush=True)
        command = ["xcodebuild", *arguments, "-resultBundlePath", str(bundle)]
        result = subprocess.run(command)
        if result.returncode != 0:
            print(f"xcodebuild failed ({result.returncode}); retained result: {bundle}", file=sys.stderr)
            return result.returncode if result.returncode > 0 else 1
        verification_args = [str(bundle), "--minimum-tests", str(args.minimum_tests), "--output", str(evidence)]
        for selector in required:
            verification_args.extend(["--require", selector])
        status = verify_result(verification_args)
        if status == 0:
            print(f"Verified evidence: {evidence}", flush=True)
        return status
    except (VerificationError, OSError) as error:
        print(f"Verified test run failed: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Test run interrupted; no successful verification was issued.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
