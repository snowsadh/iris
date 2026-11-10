"""Start Allfedo locally with a private provider key and a licensed AI Hub image."""

from __future__ import annotations

import argparse
import getpass
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import webbrowser

import iris_runtime as runtime


PROJECT = Path(__file__).resolve().parents[1]
SETTINGS = PROJECT / ".env"


def save_settings(path: Path, values: dict[str, str]) -> None:
    """Replace only the selected settings; preserve other configuration and permissions."""
    if path.is_symlink():
        raise ValueError("The private .env file must not be a symbolic link.")
    previous = path.read_text() if path.exists() else (PROJECT / ".env.example").read_text()
    remaining = dict(values)
    lines = []
    for line in previous.splitlines():
        name = line.partition("=")[0].strip()
        if name not in values:
            lines.append(line)
        elif name in remaining:
            value = remaining.pop(name)
            if "\n" in value or "\r" in value:
                raise ValueError("Settings must be single-line values.")
            lines.append(name + "='" + value.replace("'", "\\'") + "'")
    for name, value in remaining.items():
        if "\n" in value or "\r" in value:
            raise ValueError("Settings must be single-line values.")
        lines.append(name + "='" + value.replace("'", "\\'") + "'")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=".env.setup.", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write("\n".join(lines) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        temporary.chmod(0o600)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def configure_provider() -> None:
    if SETTINGS.is_symlink():
        raise ValueError("The private .env file must not be a symbolic link.")
    if SETTINGS.exists():
        SETTINGS.chmod(0o600)
        existing = dict(re.findall(r"^([A-Z_]+)=(.*)$", SETTINGS.read_text(), re.M))
        def value(name: str, default: str = "") -> str:
            raw = existing.get(name, default).strip()
            if raw.startswith(("'", '"')):
                return raw[1:].split(raw[0], 1)[0]
            return raw.split("#", 1)[0].strip()

        provider = value("AI_PROVIDER", "openai")
        if ("AI_PROVIDER" in existing and "AI_API_KEY" in existing) or (provider == "openai" and value("OPENAI_API_KEY")):
            print("Using your existing private AI configuration.")
            return
    provider = input("AI provider: openai, openrouter or gemini [openai]: ").strip().lower() or "openai"
    if provider not in {"openai", "openrouter", "gemini"}:
        raise ValueError("Choose openai, openrouter or gemini.")
    key = getpass.getpass("Your API key (hidden; leave empty for manual planning): ").strip()
    model = input("Model ID [Enter for the suggested model]: ").strip() if key else ""
    if model and not re.fullmatch(r"[A-Za-z0-9._:/-]{1,150}", model):
        raise ValueError("Use a model ID with no spaces.")
    save_settings(SETTINGS, {"AI_PROVIDER": provider, "AI_API_KEY": key, "AI_MODEL": model})
    print("Saved private settings. Keys are never included in the repository.")


def select_image(archive: Path | None) -> None:
    if archive is not None:
        runtime.install(archive.expanduser())
        return
    if (PROJECT / "compose.override.yaml").exists():
        return
    for build in sorted(runtime.SUPPORTED_BUILDS, reverse=True):
        image = f"food-rescue/iris-aihub:{build}"
        if subprocess.run(["docker", "image", "inspect", image], capture_output=True).returncode == 0:
            runtime.write_runtime_override(PROJECT / "compose.override.yaml", image, build)
            return
    downloads = sorted((Path.home() / "Downloads").glob("iris-community-*-docker.tar*"), key=lambda path: path.stat().st_mtime, reverse=True)
    if downloads:
        print(f"Using the licensed archive in Downloads: {downloads[0].name}")
        runtime.install(downloads[0])
        return
    print("Download an AI Hub Community Docker archive from https://evaluation.intersystems.com/Eval/early-access/AIHub")
    location = input("Path to the downloaded archive: ").strip()
    if not location:
        raise ValueError("Download the licensed AI Hub image, then rerun setup with its path.")
    runtime.install(Path(location).expanduser())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, nargs="?", help="Optional path to the licensed AI Hub archive")
    parser.add_argument("--open", action="store_true", help="Open six signed-in partner windows; requires the optional Playwright tools")
    args = parser.parse_args()
    if not shutil.which("docker"):
        raise RuntimeError("Install Docker with Compose, then rerun this command.")
    if subprocess.run(["docker", "info", "--format", "{{.ServerVersion}}"], capture_output=True).returncode:
        raise RuntimeError("Start Docker, then rerun this command.")
    configure_provider()
    select_image(args.archive)
    # Refresh environment and bind mounts while preserving the named data volumes.
    subprocess.run(runtime._compose_command("up", "-d", "--force-recreate", "iris", "mailpit"), cwd=PROJECT, check=True)
    runtime.configure_application()
    subprocess.run([sys.executable, str(PROJECT / "scripts" / "demo.py"), *(["--open"] if args.open else [])], cwd=PROJECT, check=True)
    if not args.open:
        import demo
        webbrowser.open(demo.browser_url())


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        raise SystemExit(f"Setup stopped: {error}") from None
    except subprocess.SubprocessError:
        raise SystemExit("Setup could not finish. Check the step reported above, then rerun; existing data is preserved.") from None
