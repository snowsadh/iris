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


def write_runtime_override(path: Path, image: str, build: str) -> None:
    """Select a literal image and fresh build-specific storage without editing .env."""
    if build not in SUPPORTED_BUILDS or image != f"food-rescue/iris-aihub:{build}":
        raise ValueError("The runtime override requires an accepted local AI Hub image.")
    marker = {"generator": "allfedo.iris_runtime", "schema": 1}
    if path.is_symlink():
        raise ValueError("Refusing to replace a linked Compose override.")
    if path.exists():
        try:
            original = json.loads(path.read_text())
        except (ValueError, UnicodeError):
            original = None
        if not isinstance(original, dict) or original.get("x-allfedo-runtime") != marker:
            raise ValueError("A foreign compose.override.yaml exists; keep it safe and move it before installing.")
    override = {
        "x-allfedo-runtime": marker,
        "services": {"iris": {"image": image}},
        "volumes": {"iris-data": {"name": f"allfedo-iris-{build}"}},
    }
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".runtime-", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(json.dumps(override, indent=2) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def _compose_command(*arguments: str) -> list[str]:
    return ["docker", "compose", "--file", str(PROJECT / "compose.yaml"),
            "--file", str(PROJECT / "compose.override.yaml"), *arguments]


def verify_native(expected_build: str, expected_image_id: str, timeout: float = 120) -> str:
    """Require the selected image, native build, successful session, and Hub classes.

    This checks an installed native runtime, not application setup, web endpoints,
    or a provider/model call. Retries share one bounded startup deadline.
    """
    if expected_build not in SUPPORTED_BUILDS:
        raise ValueError("Native verification requires an accepted AI Hub build.")
    if not re.fullmatch(r"sha256:[a-f0-9]{64}", expected_image_id):
        raise ValueError("Native verification requires the loaded Docker image ID.")
    deadline = time.monotonic() + timeout

    def probe(command: list[str], *, input: str | None = None):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(command, timeout)
        return subprocess.run(command, cwd=PROJECT, input=input, text=True,
                              capture_output=True, timeout=min(15, remaining))

    while time.monotonic() < deadline:
        try:
            containers = probe(_compose_command("ps", "--quiet", "iris"))
            ids = containers.stdout.splitlines() if containers.returncode == 0 else []
            if len(ids) == 1 and ids[0].strip():
                container_id = ids[0].strip()
                image = probe(["docker", "inspect", "--format", "{{.Image}}", container_id])
                if image.returncode == 0:
                    if image.stdout.strip() != expected_image_id:
                        raise RuntimeError("The running IRIS container does not use the loaded image.")
                    result = probe(["docker", "exec", "-i", container_id, "iris", "session", "IRIS", "-U", "%SYS"], input=PROBE)
                    version = re.search(r"(?m)^FOOD_RESCUE_VERSION=([^\r\n]+)\r?$", result.stdout)
                    if result.returncode == 0 and version:
                        actual_version = version.group(1).strip()
                        build = re.search(r"\b(\d{4}\.\d+\.\d+(?:AI)?)\s+\(Build (\d+)(?:\.(\d+))?U?\)", actual_version)
                        actual_build = f"{build[1]}.{build[2]}.{build[3] or '0'}" if build else None
                        if actual_build != expected_build:
                            raise RuntimeError("The native IRIS version does not match the selected accepted build.")
                        lines = result.stdout.splitlines()
                        missing = [name for name in ("AGENT", "PROVIDER", "TOOLSET")
                                   if f"FOOD_RESCUE_{name}=1" not in lines]
                        if missing:
                            raise RuntimeError("IRIS started but required AI Hub classes were not found: " + ", ".join(missing))
                        return actual_version
        except subprocess.TimeoutExpired:
            pass
        remaining = deadline - time.monotonic()
        if remaining > 0:
            time.sleep(min(2, remaining))
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
    loaded = subprocess.run(["docker", "image", "inspect", "--format", "{{.Id}}", image],
                            check=True, capture_output=True, text=True, timeout=15)
    image_id = loaded.stdout.strip()
    write_runtime_override(PROJECT / "compose.override.yaml", image, build)
    # Quiet validation avoids printing the resolved OpenAI key from Compose configuration.
    subprocess.run(_compose_command("config", "--quiet"), cwd=PROJECT, check=True)
    subprocess.run(_compose_command("up", "-d", "iris", "mailpit"), cwd=PROJECT, check=True)
    print("Checking the actual IRIS version and AI Hub classes...", flush=True)
    print(verify_native(build, image_id), flush=True)
    print("Native AI Hub classes found. No model call or application workflow has run yet.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="AI Hub Community Docker .tar.gz downloaded from the official portal")
    args = parser.parse_args()
    try:
        install(args.archive)
    except (OSError, ValueError, RuntimeError, tarfile.TarError,
            subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"Installation not complete: {error}\n")


if __name__ == "__main__":
    main()
