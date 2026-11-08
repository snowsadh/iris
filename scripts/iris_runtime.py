"""Load a licensed AI Hub archive, start local services, and verify native classes."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tarfile
import tempfile
import time


PROJECT = Path(__file__).resolve().parents[1]
SUPPORTED_BUILDS = frozenset({"2027.1.0AI.109.0", "2026.3.0AI.154.0"})
PROBE = '''Write !,"FOOD_RESCUE_VERSION=",$ZVERSION,!
Write "FOOD_RESCUE_AGENT=",##class(%Dictionary.CompiledClass).%ExistsId("%AI.Agent"),!
Write "FOOD_RESCUE_PROVIDER=",##class(%Dictionary.CompiledClass).%ExistsId("%AI.Provider"),!
Write "FOOD_RESCUE_TOOLSET=",##class(%Dictionary.CompiledClass).%ExistsId("%AI.ToolSet"),!
Halt
'''


def inspect_archive(archive: Path, expected_arch: str) -> tuple[str, str]:
    """Read small metadata entries without extracting files or retaining image layers."""
    metadata = {}
    manifest = None
    with tarfile.open(archive, "r|*") as bundle:
        for member in bundle:
            if not member.isfile() or member.size > 2 * 1024 * 1024:
                continue
            stream = bundle.extractfile(member)
            if stream is None:
                continue
            try:
                value = json.loads(stream.read())
            except (ValueError, UnicodeDecodeError):
                continue
            if member.name.removeprefix("./") == "manifest.json":
                manifest = value
            elif isinstance(value, dict) and "architecture" in value:
                metadata[member.name.removeprefix("./")] = value
            if not isinstance(manifest, list):
                continue
            candidates = []
            for item in manifest:
                if not isinstance(item, dict):
                    continue
                for tag in item.get("RepoTags") or []:
                    repository, _, build = tag.rpartition(":")
                    if build in SUPPORTED_BUILDS and repository.rsplit("/", 1)[-1] in {
                        "iris-community", "irishealth-community"
                    }:
                        candidates.append((tag, build, item.get("Config", "").removeprefix("./")))
            identities = {(build, config) for _, build, config in candidates}
            if len(identities) > 1:
                raise ValueError("The archive contains several accepted images; use one vendor image archive.")
            if candidates and candidates[0][2] in metadata:
                source, build, config = candidates[0]
                info = metadata[config]
                if info.get("os") != "linux" or info["architecture"] != expected_arch:
                    raise ValueError(f"Image platform must be linux/{expected_arch} for this machine.")
                return source, build
    raise ValueError("Archive must contain an accepted IRIS AI Hub Community Docker image and its metadata.")


def update_environment(path: Path, image: str) -> None:
    """Preserve private settings and atomically change only the local image setting."""
    original = path.read_text() if path.exists() else ""
    lines = [line for line in original.splitlines() if not re.match(r"^\s*(?:export\s+)?IRIS_IMAGE\s*=", line)]
    lines.append(f"IRIS_IMAGE={image}")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".env.", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write("\n".join(lines) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def verify_native(timeout: float = 120) -> str:
    """Wait for a native terminal and require compiled Hub classes, not just a port."""
    deadline = time.monotonic() + timeout
    command = ["docker", "compose", "exec", "-T", "iris", "iris", "session", "IRIS", "-U", "%SYS"]
    while time.monotonic() < deadline:
        try:
            result = subprocess.run(command, cwd=PROJECT, input=PROBE, text=True,
                                    capture_output=True, timeout=15)
        except subprocess.TimeoutExpired:
            continue
        version = re.search(r"(?m)^FOOD_RESCUE_VERSION=(.+)$", result.stdout)
        if version:
            missing = [name for name in ("AGENT", "PROVIDER", "TOOLSET")
                       if f"FOOD_RESCUE_{name}=1" not in result.stdout]
            if missing:
                raise RuntimeError("IRIS started but required AI Hub classes were not found: " + ", ".join(missing))
            return version.group(1).strip()
        time.sleep(2)
    raise RuntimeError("Native IRIS verification timed out. Inspect this project's IRIS startup logs locally.")


def install(archive: Path) -> None:
    archive = archive.expanduser().resolve(strict=True)
    architecture = {"x86_64": "amd64", "aarch64": "arm64", "arm64": "arm64"}.get(platform.machine())
    if architecture is None:
        raise ValueError("This installer supports amd64 and arm64 hosts.")
    print("Checking the licensed archive's build and platform...", flush=True)
    source, build = inspect_archive(archive, architecture)
    subprocess.run(["docker", "compose", "version"], cwd=PROJECT, check=True)
    print(f"Loading AI Hub Community build {build} for {architecture}...", flush=True)
    subprocess.run(["docker", "image", "load", "--quiet", "--input", str(archive)], check=True)
    image = f"food-rescue/iris-aihub:{build}"
    subprocess.run(["docker", "image", "tag", source, image], check=True)
    update_environment(PROJECT / ".env", image)
    # Quiet validation avoids printing the resolved OpenAI key from Compose configuration.
    subprocess.run(["docker", "compose", "config", "--quiet"], cwd=PROJECT, check=True)
    subprocess.run(["docker", "compose", "up", "-d", "iris", "mailpit"], cwd=PROJECT, check=True)
    print("Checking the actual IRIS version and AI Hub classes...", flush=True)
    print(verify_native(), flush=True)
    print("Native AI Hub classes found. No model call or application workflow has run yet.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="AI Hub Community Docker .tar.gz downloaded from the official portal")
    args = parser.parse_args()
    try:
        install(args.archive)
    except (OSError, ValueError, RuntimeError, tarfile.TarError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Installation not complete: {error}\n")


if __name__ == "__main__":
    main()
