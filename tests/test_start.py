"""Private setup changes preserve other settings and never expand key characters."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("allfedo_start", SCRIPTS / "start.py")
start = importlib.util.module_from_spec(spec)
spec.loader.exec_module(start)
sys.path.pop(0)


class PrivateSetupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / ".env"
        self.path.write_text("# Existing deployment\nIRIS_WEB_PORT=52774\nAI_API_KEY=old\nAI_API_KEY=duplicate\n")

    def test_replacement_preserves_other_settings_and_sets_private_permissions(self):
        start.save_settings(self.path, {"AI_API_KEY": "synthetic-key", "AI_PROVIDER": "openai"})
        result = self.path.read_text()
        self.assertIn("# Existing deployment\nIRIS_WEB_PORT=52774\n", result)
        self.assertEqual(result.count("AI_API_KEY="), 1)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_existing_provider_and_manual_choices_need_no_more_prompts(self):
        for settings in ("AI_PROVIDER=gemini\nAI_API_KEY='synthetic-key'\n", "OPENAI_API_KEY=synthetic-key\n", "AI_PROVIDER=openai\nAI_API_KEY=''\n"):
            with self.subTest(settings=settings):
                self.path.write_text(settings)
                with patch.object(start, "SETTINGS", self.path), patch("builtins.input", side_effect=AssertionError("Unexpected prompt")), patch.object(start.getpass, "getpass", side_effect=AssertionError("Unexpected key prompt")):
                    start.configure_provider()

    def test_symlink_and_failed_replacement_leave_existing_settings_alone(self):
        link = self.path.with_name("linked.env")
        link.symlink_to(self.path)
        previous = self.path.read_bytes()
        with self.assertRaises(ValueError):
            start.save_settings(link, {"AI_API_KEY": "synthetic-key"})
        with patch.object(start.os, "replace", side_effect=OSError("Synthetic failure")):
            with self.assertRaises(OSError):
                start.save_settings(self.path, {"AI_API_KEY": "synthetic-key"})
        self.assertEqual(self.path.read_bytes(), previous)
        self.assertEqual(list(self.path.parent.glob(".env.setup.*")), [])

    @unittest.skipUnless(shutil.which("docker"), "Compose verifies its own dotenv syntax.")
    def test_key_characters_survive_compose_environment_resolution(self):
        value = "synthetic$cost's\\tail"
        start.save_settings(self.path, {"AI_API_KEY": value})
        result = subprocess.run(
            ["docker", "compose", "--env-file", str(self.path), "--file", str(SCRIPTS.parent / "compose.yaml"), "config", "--environment"],
            env={"PATH": os.environ["PATH"]}, check=True, capture_output=True, text=True,
        )
        values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
        self.assertEqual(values["AI_API_KEY"], value)


if __name__ == "__main__":
    unittest.main()
