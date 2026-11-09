"""Archive/configuration and probe-contract checks, not a live IRIS installation."""

import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch


module_path = Path(__file__).resolve().parents[1] / "scripts" / "iris_runtime.py"
spec = importlib.util.spec_from_file_location("iris_runtime", module_path)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class RuntimeSetupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def archive(self, *, build="2027.1.0AI.109.0", architecture="amd64", manifest_first=True):
        path = self.root / "image with spaces.tar.gz"
        config = "blobs/sha256/current-config"
        entries = {
            "manifest.json": [{"Config": config, "RepoTags": [f"vendor/iris-community:{build}"]}],
            config: {"architecture": architecture, "os": "linux"},
            "blobs/sha256/unrelated-attestation": {"architecture": "unknown", "os": "unknown"},
        }
        with tarfile.open(path, "w:gz") as bundle:
            for name in sorted(entries, reverse=manifest_first):
                data = json.dumps(entries[name]).encode()
                member = tarfile.TarInfo(name)
                member.size = len(data)
                bundle.addfile(member, io.BytesIO(data))
        return path

    def test_vendor_metadata_order_does_not_matter(self):
        for first in (True, False):
            with self.subTest(manifest_first=first):
                source, build = runtime.inspect_archive(self.archive(manifest_first=first), "amd64")
                self.assertEqual(build, "2027.1.0AI.109.0")
                self.assertEqual(source, "vendor/iris-community:2027.1.0AI.109.0")

    def test_standard_release_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "accepted"):
            runtime.inspect_archive(self.archive(build="2026.2.0"), "amd64")

    def test_wrong_machine_image_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "platform"):
            runtime.inspect_archive(self.archive(architecture="arm64"), "amd64")

    def test_selecting_and_changing_build_preserves_settings_and_separates_storage(self):
        env = self.root / ".env"
        private_settings = b"PRIVATE_NOTES='line one\r\nIRIS_IMAGE=private text\r\nline three'\r\nIRIS_IMAGE=old\r\n"
        env.write_bytes(private_settings)
        override = self.root / "compose.override.yaml"
        names = []
        for build in ("2026.3.0AI.154.0", "2027.1.0AI.109.0"):
            image = f"food-rescue/iris-aihub:{build}"
            runtime.write_runtime_override(override, image, build)
            settings = json.loads(override.read_text())
            for service in ("iris", "iris-data-init"):
                self.assertEqual(settings["services"][service]["image"], image)
            self.assertNotIn("${", override.read_text())
            names.append(settings["volumes"]["iris-data"]["name"])
            self.assertEqual(env.read_bytes(), private_settings)
        self.assertEqual(names, ["allfedo-iris-2026.3.0AI.154.0", "allfedo-iris-2027.1.0AI.109.0"])
        self.assertEqual(sorted(path.name for path in self.root.iterdir()), [".env", "compose.override.yaml"])

    def test_foreign_override_is_never_replaced(self):
        override = self.root / "compose.override.yaml"
        for original in ('services:\n  iris:\n    image: custom\n', '{"services":{"iris":{"image":"custom"}}}'):
            with self.subTest(original=original):
                override.write_text(original)
                with self.assertRaisesRegex(ValueError, "foreign"):
                    runtime.write_runtime_override(override, "food-rescue/iris-aihub:2027.1.0AI.109.0", "2027.1.0AI.109.0")
                self.assertEqual(override.read_text(), original)

    def test_failed_atomic_replacement_keeps_previous_selection_and_cleans_temporary_file(self):
        override = self.root / "compose.override.yaml"
        runtime.write_runtime_override(override, "food-rescue/iris-aihub:2026.3.0AI.154.0", "2026.3.0AI.154.0")
        previous = override.read_bytes()
        with patch.object(runtime.os, "replace", side_effect=OSError("test replacement failure")):
            with self.assertRaises(OSError):
                runtime.write_runtime_override(override, "food-rescue/iris-aihub:2027.1.0AI.109.0", "2027.1.0AI.109.0")
        self.assertEqual(override.read_bytes(), previous)
        self.assertEqual(list(self.root.iterdir()), [override])

    @unittest.skipUnless(shutil.which("docker"), "Docker Compose checks the deployment configuration.")
    def test_compose_initializes_only_its_volume_before_starting_unprivileged_iris(self):
        base, override, settings = (self.root / name for name in ("compose.yaml", "compose.override.yaml", "empty.env"))
        base.write_text((runtime.PROJECT / "compose.yaml").read_text())
        settings.write_text("")
        image = "food-rescue/iris-aihub:2027.1.0AI.109.0"
        runtime.write_runtime_override(override, image, "2027.1.0AI.109.0")
        result = subprocess.run(
            ["docker", "compose", "--file", str(base), "--file", str(override),
             "--env-file", str(settings), "config", "--format", "json"],
            cwd=self.root, env={"PATH": os.environ["PATH"], "IRIS_IMAGE": "stale-exported:image",
                                "COMPOSE_FILE": "missing-foreign.yaml"},
            check=True, capture_output=True, text=True, timeout=15,
        )
        merged = json.loads(result.stdout)
        init, iris = (merged["services"][name] for name in ("iris-data-init", "iris"))
        self.assertEqual(init["image"], image)
        self.assertEqual(iris["image"], image)
        self.assertEqual(init["pull_policy"], "never")
        self.assertEqual(init["user"], "root")
        self.assertNotIn("user", iris)
        self.assertEqual(init["entrypoint"], ["/bin/sh"])
        self.assertEqual(init["command"], ["-c", "chown irisowner:irisowner /durable"])
        self.assertEqual([(mount["source"], mount["target"]) for mount in init["volumes"]], [("iris-data", "/durable")])
        self.assertEqual(iris["depends_on"]["iris-data-init"]["condition"], "service_completed_successfully")
        self.assertEqual(merged["volumes"]["iris-data"]["name"], "allfedo-iris-2027.1.0AI.109.0")
        self.assertEqual(iris["environment"]["PYTHONPATH"], "/opt/allfedo/python:/usr/irissys/lib/python:/usr/irissys/mgr/python")


class NativeProbeContractTests(unittest.TestCase):
    BUILD = "2027.1.0AI.109.0"
    IMAGE_ID = "sha256:" + "a" * 64

    def setUp(self):
        self.clock = 0
        self.calls = []
        self.container_image = self.IMAGE_ID
        self.version = "IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2027.1.0AI (Build 109U)"
        self.flags = {"AGENT": "1", "PROVIDER": "1", "TOOLSET": "1"}
        self.session_exit_code = 0
        self.session_output_prefix = ""
        self.timeouts_left = 0

    def run_command(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if self.timeouts_left:
            self.timeouts_left -= 1
            raise subprocess.TimeoutExpired(command, kwargs["timeout"])
        if command[1] == "compose":
            return subprocess.CompletedProcess(command, 0, "current-container\n", "")
        if command[1] == "inspect":
            return subprocess.CompletedProcess(command, 0, self.container_image + "\n", "")
        if command[1] == "exec":
            output = self.session_output_prefix + "FOOD_RESCUE_VERSION=" + self.version + "\r\n"
            output += "".join(f"FOOD_RESCUE_{name}={value}\r\n" for name, value in self.flags.items())
            return subprocess.CompletedProcess(command, self.session_exit_code, output, "")
        raise AssertionError(f"Unexpected command: {command}")

    def advance_clock(self, seconds):
        self.clock += seconds

    def test_terminal_error_cannot_pass_despite_zero_exit_and_later_success_markers(self):
        self.session_output_prefix = "<SYNTAX>\r\n"
        with self.assertRaisesRegex(RuntimeError, "ObjectScript error"):
            self.verify()

    def verify(self, timeout=4):
        with patch.object(runtime.subprocess, "run", side_effect=self.run_command), \
             patch.object(runtime.time, "monotonic", side_effect=lambda: self.clock), \
             patch.object(runtime.time, "sleep", side_effect=self.advance_clock):
            return runtime.verify_native(self.BUILD, self.IMAGE_ID, timeout=timeout)

    def test_native_success_requires_the_loaded_image_and_checks_that_same_container(self):
        self.assertEqual(self.verify(), self.version)
        inspect = next(command for command, _ in self.calls if command[1] == "inspect")
        execute = next(command for command, _ in self.calls if command[1] == "exec")
        self.assertEqual(inspect[-1], "current-container")
        self.assertEqual(execute[3], "current-container")
        self.assertEqual(self.calls[-1][1]["input"], runtime.PROBE)
        compose = self.calls[0][0]
        self.assertIn(str(runtime.PROJECT / "compose.yaml"), compose)
        self.assertIn(str(runtime.PROJECT / "compose.override.yaml"), compose)

    def test_another_running_image_cannot_pass_even_if_its_native_classes_exist(self):
        self.container_image = "sha256:" + "b" * 64
        with self.assertRaisesRegex(RuntimeError, "loaded image"):
            self.verify()
        self.assertFalse(any(command[1] == "exec" for command, _ in self.calls))

    def test_native_release_build_and_nonzero_patch_must_match_the_selected_archive(self):
        for release, build in (("2026.3.0AI", "154U"), ("2027.1.0AI", "108U"), ("2027.1.0AI", "109.1U")):
            with self.subTest(release=release, build=build):
                self.version = f"IRIS for UNIX {release} (Build {build})"
                with self.assertRaisesRegex(RuntimeError, "selected accepted build"):
                    self.verify()
        self.version = "IRIS for UNIX 2027.1.0AI (Build 109.0U)"
        self.assertEqual(self.verify(), self.version)

    def test_class_flags_are_complete_lines_with_exact_value_one(self):
        for flag in ("0", "10", "1extra"):
            with self.subTest(flag=flag):
                self.flags["AGENT"] = flag
                with self.assertRaisesRegex(RuntimeError, "AGENT"):
                    self.verify()

    def test_failed_session_does_not_pass_despite_success_markers(self):
        self.session_exit_code = 1
        with self.assertRaisesRegex(RuntimeError, "timed out"):
            self.verify(timeout=1)
        self.assertEqual(self.clock, 1)

    def test_temporary_probe_timeout_can_retry_with_one_total_deadline(self):
        self.timeouts_left = 1
        self.assertEqual(self.verify(timeout=3), self.version)
        self.assertEqual(self.clock, 2)
        self.assertTrue(all(0 < arguments["timeout"] <= 3 for _, arguments in self.calls))


if __name__ == "__main__":
    unittest.main()
