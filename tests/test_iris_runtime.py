"""Archive/configuration checks; these do not simulate successful IRIS startup."""

import importlib.util
import io
import json
from pathlib import Path
import stat
import tarfile
import tempfile
import unittest


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
        entries = {
            "manifest.json": [{"Config": "config.json", "RepoTags": [f"vendor/iris-community:{build}"]}],
            "config.json": {"architecture": architecture, "os": "linux"},
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

    def test_changing_image_preserves_private_settings(self):
        env = self.root / ".env"
        env.write_text("OPENAI_API_KEY=local-test-value\nOPENAI_MODEL=chosen-model\nIRIS_IMAGE=old\n")
        runtime.update_environment(env, "food-rescue/iris-aihub:2027.1.0AI.109.0")
        contents = env.read_text()
        self.assertIn("OPENAI_API_KEY=local-test-value\n", contents)
        self.assertIn("OPENAI_MODEL=chosen-model\n", contents)
        self.assertEqual(contents.count("IRIS_IMAGE="), 1)
        self.assertEqual(stat.S_IMODE(env.stat().st_mode), 0o600)


if __name__ == "__main__":
    unittest.main()
