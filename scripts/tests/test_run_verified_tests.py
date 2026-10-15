import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from test_verify_xcresult import verifier


SPEC = importlib.util.spec_from_file_location(
    "run_verified_tests", Path(__file__).resolve().parents[1] / "run_verified_tests.py"
)
runner = importlib.util.module_from_spec(SPEC)
with patch.dict(sys.modules, {"verify_xcresult": verifier}):
    SPEC.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="adonis-runner-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def run_main(self, arguments):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return runner.main(["--result-root", str(self.root), *arguments])

    def test_verifies_the_exact_result_of_each_run_without_shared_latest_lookup(self):
        paths = []
        with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            with patch.object(runner, "verify_result", return_value=0) as verify:
                for _ in range(2):
                    self.assertEqual(self.run_main(["--", "-project", "project with space.xcodeproj", "test"]), 0)
                    command = run.call_args.args[0]
                    self.assertEqual(command[0], "xcodebuild")
                    self.assertIn("project with space.xcodeproj", command)
                    bundle = command[-1]
                    self.assertEqual(command[-2], "-resultBundlePath")
                    self.assertEqual(verify.call_args.args[0][0], bundle)
                    self.assertEqual(Path(bundle).parent, Path(verify.call_args.args[0][-1]).parent)
                    self.assertNotIn("shell", run.call_args.kwargs)
                    paths.append(bundle)
        self.assertNotEqual(paths[0], paths[1])

    def test_nonzero_xcode_exit_is_preserved_and_never_verified_as_success(self):
        for code in (65, -9):
            with self.subTest(code=code), patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], code)):
                with patch.object(runner, "verify_result") as verify:
                    self.assertEqual(self.run_main(["--", "test"]), code if code > 0 else 1)
                    verify.assert_not_called()

    def test_failed_result_verification_fails_the_runner(self):
        with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            with patch.object(runner, "verify_result", return_value=1):
                self.assertEqual(self.run_main(["--", "test"]), 1)

    def test_only_testing_arguments_become_required_coverage(self):
        with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            with patch.object(runner, "verify_result", return_value=0) as verify:
                self.assertEqual(self.run_main([
                    "--minimum-tests", "6", "--require", "AdonisUITests", "--", "test",
                    "-only-testing:AdonisTests/PhotoLibrarySaverTests",
                    "-only-testing:AdonisUITests/AdonisFlowUITests/testPreparedStickerCanBeSavedToPhotosWithoutLeavingResult",
                ]), 0)
                arguments = verify.call_args.args[0]
                self.assertEqual(arguments[arguments.index("--minimum-tests") + 1], "6")
                required = [arguments[index + 1] for index, item in enumerate(arguments) if item == "--require"]
                self.assertEqual(len(required), 3)
                self.assertIn("AdonisTests/PhotoLibrarySaverTests", required)

    def test_empty_selector_or_override_or_build_only_is_rejected_before_running(self):
        for arguments in (["--", "build"], ["--", "test", "-resultBundlePath", "old.xcresult"],
                          ["--", "test", "-only-testing:"], ["--", "test", "-resultBundlePath=old.xcresult"]):
            with self.subTest(arguments=arguments), patch.object(runner.subprocess, "run") as run:
                self.assertEqual(self.run_main(arguments), 1)
                run.assert_not_called()

    def test_space_and_colon_selectors_both_require_every_named_method(self):
        with patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            with patch.object(runner, "verify_result", return_value=1) as verify:
                self.assertEqual(self.run_main([
                    "--", "test", "-only-testing", "Target/Suite/testPasses",
                    "-only-testing", "Target/Suite/testDoesNotExist",
                    "-only-testing:Target/Suite/testPasses()",
                ]), 1)
                arguments = verify.call_args.args[0]
                required = [arguments[index + 1] for index, item in enumerate(arguments) if item == "--require"]
                self.assertEqual(required, ["Target/Suite/testDoesNotExist", "Target/Suite/testPasses"])

    def test_space_selector_requires_a_value_before_launching_xcode(self):
        for suffix in (["-only-testing"], ["-only-testing", ""], ["-only-testing", "-quiet"]):
            with self.subTest(suffix=suffix), patch.object(runner.subprocess, "run") as run:
                self.assertEqual(self.run_main(["--", "test", *suffix]), 1)
                run.assert_not_called()

    def test_interrupt_and_missing_tool_cannot_issue_success(self):
        for error, code in ((KeyboardInterrupt(), 130), (FileNotFoundError(), 1)):
            with self.subTest(error=error), patch.object(runner.subprocess, "run", side_effect=error):
                with patch.object(runner, "verify_result") as verify:
                    self.assertEqual(self.run_main(["--", "test"]), code)
                    verify.assert_not_called()


if __name__ == "__main__":
    unittest.main()
