"""Load a licensed AI Hub archive, start local services, and verify native classes."""

from __future__ import annotations

import argparse
import hashlib
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


def _terminal_error(output: str) -> bool:
    # IRIS's interactive terminal may continue after an error and still exit zero.
    return re.search(r"(?m)^\s*<[A-Z][A-Z0-9 -]*>", output) is not None


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
        "services": {"iris": {"image": image}, "iris-data-init": {"image": image}},
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
                    if _terminal_error(result.stdout):
                        raise RuntimeError("Native verification reported an ObjectScript error; inspect the local terminal output.")
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


def _verify_selected_runtime() -> str:
    """Require this installer's selected image and the matching running native build."""
    selection = json.loads((PROJECT / "compose.override.yaml").read_text())
    if selection.get("x-allfedo-runtime") != {"generator": "allfedo.iris_runtime", "schema": 1}:
        raise ValueError("Run the archive installer before application setup.")
    image = selection.get("services", {}).get("iris", {}).get("image", "")
    build = image.removeprefix("food-rescue/iris-aihub:")
    if build not in SUPPORTED_BUILDS or image != f"food-rescue/iris-aihub:{build}":
        raise ValueError("Application setup requires a selected accepted AI Hub image.")
    loaded = subprocess.run(["docker", "image", "inspect", "--format", "{{.Id}}", image],
                            check=True, capture_output=True, text=True, timeout=15)
    return verify_native(build, loaded.stdout.strip())


def configure_application() -> None:
    """Create the isolated application namespace and compile the mounted source."""
    _verify_selected_runtime()
    # A branch switch can replace a bind-mounted directory while Docker keeps its old inode.
    sources = sorted(path for path in (PROJECT / "src").rglob("*")
                     if path.is_file() and path.suffix in {".cls", ".py", ".js", ".css", ".html", ".svg", ".ttf"})
    expected = [hashlib.sha256(path.read_bytes()).hexdigest() for path in sources]
    names = ["/opt/allfedo/" + path.relative_to(PROJECT / "src").as_posix() for path in sources]
    mounted = subprocess.run(_compose_command("exec", "-T", "iris", "sha256sum", *names),
                             cwd=PROJECT, capture_output=True, text=True, timeout=30)
    if mounted.returncode or [line.split()[0] for line in mounted.stdout.splitlines()] != expected:
        raise RuntimeError("Docker's mounted source does not match this checkout. Run "
                           "`docker compose up -d --force-recreate iris`, then rerun setup. "
                           "Existing data volumes are preserved.")
    # Each terminal input line must be complete; compiled ObjectScript supports multiline blocks.
    prepare = '''Set sc=1, wasRunning=0
If ##class(%SYS.Namespace).Exists("ALLFEDO") { ZN "ALLFEDO" Set wasRunning=##class(Ens.Director).IsProductionRunning(.production) If wasRunning { If production'="Allfedo.Production" { Set sc=0 Write !,"A different Production owns ALLFEDO; stop it explicitly before setup.",! } Else { Set sc=##class(Ens.Director).StopProduction() } } }
If 'sc Do $SYSTEM.Status.DisplayError(sc)
Write !,"ALLFEDO_PREPARED=",(sc=1),!
Halt
'''
    prepared = subprocess.run(_compose_command("exec", "-T", "iris", "iris", "session", "IRIS", "-U", "%SYS"),
                              cwd=PROJECT, input=prepare, text=True, capture_output=True, timeout=60)
    if prepared.returncode != 0 or _terminal_error(prepared.stdout) or "ALLFEDO_PREPARED=1" not in prepared.stdout.splitlines():
        print(prepared.stdout, end="")
        raise RuntimeError("The running Production could not be stopped safely before setup.")
    subprocess.run(_compose_command("cp", str(PROJECT / "scripts" / "namespace.cpf"),
                                    "iris:/tmp/allfedo-namespace.cpf"), cwd=PROJECT, check=True)
    subprocess.run(_compose_command("exec", "-T", "iris", "iris", "merge", "IRIS",
                                    "/tmp/allfedo-namespace.cpf"), cwd=PROJECT, check=True, timeout=120)
    commands = '''Set sc=$SYSTEM.OBJ.LoadDir("/opt/allfedo/Allfedo","ck",,1)
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc Set sc=##class(Allfedo.Web.Setup).Configure()
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc Set sc=##class(Ens.Director).SetAutoStart("Allfedo.Production")
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc Set sc=##class(Ens.Director).StartProduction("Allfedo.Production")
If 'sc Do $SYSTEM.Status.DisplayError(sc)
Write !,"ALLFEDO_COMPILED=",(sc=1),!
Halt
'''
    result = subprocess.run(_compose_command("exec", "-T", "iris", "iris", "session", "IRIS", "-U", "ALLFEDO"),
                            cwd=PROJECT, input=commands, text=True, capture_output=True, timeout=120)
    if result.returncode != 0 or _terminal_error(result.stdout) or "ALLFEDO_COMPILED=1" not in result.stdout.splitlines():
        print(result.stdout, end="")
        raise RuntimeError("Application compilation did not succeed. Review the compiler messages above.")
    print("Allfedo compiled, its web routes configured, and its Production started. Partner accounts and model calls are separate steps.")


def test_application() -> None:
    """Run real native command and two-process capacity checks without model calls."""
    _verify_selected_runtime()
    for filename in ("AllfedoScenario.cls", "AllfedoWebScenario.cls", "AllfedoAgentScenario.cls", "AllfedoMailScenario.cls"):
        subprocess.run(_compose_command("cp", str(PROJECT / "tests" / "native" / filename),
                                        f"iris:/tmp/{filename}"), cwd=PROJECT, check=True)
    commands = '''Set sc=##class(Ens.Director).IsProductionRunning(.production)
If 'sc||(production'="Allfedo.Production") { Set sc=0 Write !,"Start Allfedo with --setup before running native checks.",! }
If sc Set sc=$SYSTEM.OBJ.Load("/tmp/AllfedoScenario.cls","ck")
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc Set sc=$SYSTEM.OBJ.Load("/tmp/AllfedoWebScenario.cls","ck")
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc Set sc=$SYSTEM.OBJ.Load("/tmp/AllfedoAgentScenario.cls","ck")
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc Set sc=$SYSTEM.OBJ.Load("/tmp/AllfedoMailScenario.cls","ck")
If 'sc Do $SYSTEM.Status.DisplayError(sc)
If sc { Set result=##class(AllfedoScenario).TestCommands() Write !,"ALLFEDO_COMMANDS=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestArithmeticGuards() Write !,"ALLFEDO_ARITHMETIC=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestRaces() Write !,"ALLFEDO_RACES=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestBusyRecovery() Write !,"ALLFEDO_BUSY=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestFacts() Write !,"ALLFEDO_FACTS=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestProductionLocks() Write !,"ALLFEDO_WORKERS=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestRecovery() Write !,"ALLFEDO_RECOVERY=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestRedirect() Write !,"ALLFEDO_REDIRECT=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoScenario).TestRejectedTransfer() Write !,"ALLFEDO_REJECTED=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoAgentScenario).TestUnavailable() Write !,"ALLFEDO_AGENT_FAILURE=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoAgentScenario).TestSettings() Write !,"ALLFEDO_AI_SETTINGS=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoMailScenario).Run() Write !,"ALLFEDO_MAIL=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoMailScenario).TestRedirectNotices() Write !,"ALLFEDO_MAIL_REDIRECT=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoMailScenario).TestStaleRedirectNotices() Write !,"ALLFEDO_MAIL_STALE=",result.%ToJSON(),! }
If sc { Set result=##class(AllfedoMailScenario).TestScheduled() Write !,"ALLFEDO_SMTP=",result.%ToJSON(),! }
If sc Write !,"ALLFEDO_HTTP=",##class(AllfedoWebScenario).Run(),!
If sc Write !,"ALLFEDO_HTTP_REDIRECT=",##class(AllfedoWebScenario).Run("http://127.0.0.1:52773/allfedo/api","redirect"),!
If sc Write !,"ALLFEDO_HTTP_REJECTED=",##class(AllfedoWebScenario).Run("http://127.0.0.1:52773/allfedo/api","rejected"),!
Halt
'''
    # The direct agent-failure check cannot contact a provider. Existing Production workers keep their own environment.
    result = subprocess.run(_compose_command("exec", "-T", "--env", "OPENAI_API_KEY=", "--env", "AI_API_KEY=", "--env", "AI_DAILY_LIMIT=1", "iris", "iris", "session", "IRIS", "-U", "ALLFEDO"),
                            cwd=PROJECT, input=commands, text=True, capture_output=True, timeout=180)
    names = (
        "COMMANDS", "ARITHMETIC", "RACES", "BUSY", "FACTS", "WORKERS", "RECOVERY", "REDIRECT",
        "REJECTED", "AGENT_FAILURE", "AI_SETTINGS", "MAIL", "MAIL_REDIRECT", "MAIL_STALE", "SMTP",
        "HTTP", "HTTP_REDIRECT", "HTTP_REJECTED",
    )
    checks = {}
    for line in result.stdout.splitlines():
        for name in names:
            prefix = f"ALLFEDO_{name}="
            if line.startswith(prefix):
                try:
                    value = json.loads(line.removeprefix(prefix))
                    checks[name] = value if isinstance(value, dict) else {"ok": False}
                except json.JSONDecodeError:
                    checks[name] = {"ok": False, "error": "The native check returned no readable result."}
    if result.returncode != 0 or _terminal_error(result.stdout) or any(checks.get(name, {}).get("ok") is not True for name in names):
        print(result.stdout, end="")
        raise RuntimeError("Native command or shared-capacity checks did not pass.")
    print("Native commands, shared capacity, facts, recovery, provider settings and failure, mail rules, retries, worker cleanup, and signed-in HTTP checks passed. No model call was made.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, nargs="?", help="AI Hub Community Docker .tar.gz downloaded from the official portal")
    parser.add_argument("--setup", action="store_true", help="Create ALLFEDO and compile source after installing, or on the running selected runtime")
    parser.add_argument("--test", action="store_true", help="Run native command and capacity checks; creates isolated synthetic records, no model call")
    args = parser.parse_args()
    if args.archive is None and not args.setup and not args.test:
        parser.error("Supply a vendor archive, --setup, or --test.")
    try:
        if args.archive is not None:
            install(args.archive)
        if args.setup:
            configure_application()
        if args.test:
            test_application()
    except (OSError, ValueError, RuntimeError, tarfile.TarError,
            subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"Runtime command failed: {error}\n")


if __name__ == "__main__":
    main()
