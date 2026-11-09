"""Run the browser journey with fresh native accounts; retain records, remove test logins."""

from __future__ import annotations

import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile

from iris_runtime import PROJECT, _compose_command, _terminal_error, _verify_selected_runtime


def terminal(script: str, accounts: dict) -> str:
    environment = dict(os.environ, ALLFEDO_BROWSER_FIXTURE=json.dumps(accounts))
    command = _compose_command("exec", "-T", "--env", "ALLFEDO_BROWSER_FIXTURE",
                               "iris", "iris", "session", "IRIS", "-U", "ALLFEDO")
    process = subprocess.run(command, cwd=PROJECT, env=environment, input=script + "\nHalt\n",
                             capture_output=True, text=True, timeout=90)
    if process.returncode or _terminal_error(process.stdout) or "ALLFEDO_BROWSER_OK=1" not in process.stdout.splitlines():
        # Native diagnostics may echo input: never print credentials or the environment.
        raise RuntimeError("The native browser fixture step failed. Check application setup and rerun native checks.")
    return process.stdout


def main() -> None:
    _verify_selected_runtime()
    for filename in ("AllfedoScenario.cls", "AllfedoWebScenario.cls", "AllfedoBrowserScenario.cls"):
        subprocess.run(_compose_command("cp", str(PROJECT / "tests" / "native" / filename),
                                        f"iris:/tmp/{filename}"), cwd=PROJECT, check=True, timeout=30)
    token = secrets.token_hex(6)
    accounts = {role: {"username": f"allfedo-web-test-{token}-{role}",
                       "password": secrets.token_urlsafe(32) + "9!aA"}
                for role in ("coordinator", "kitchen", "recipient", "collector", "recipient2")}
    # Keep each interactive command complete. An earlier terminal error must fail the whole step.
    load = 'Set sc=1\n' + '\n'.join(f'If sc Set sc=$SYSTEM.OBJ.Load("/tmp/{filename}","ck")'
                     for filename in ("AllfedoScenario.cls", "AllfedoWebScenario.cls", "AllfedoBrowserScenario.cls"))
    terminal(load + '\nWrite !,"ALLFEDO_BROWSER_OK=",(sc=1),!', accounts)
    try:
        output = terminal('Set fixture=##class(AllfedoBrowserScenario).PrepareFromEnvironment()\nWrite !,"ALLFEDO_BROWSER_FIXTURE=",fixture,!\nWrite "ALLFEDO_BROWSER_OK=1",!', accounts)
        line = next(value for value in output.splitlines() if value.startswith("ALLFEDO_BROWSER_FIXTURE="))
        fixture = json.loads(line.split("=", 1)[1])
        if fixture.get("ok") is not True:
            raise RuntimeError("The native fixture did not confirm its accounts.")
        port = subprocess.run(_compose_command("port", "iris", "52773"), cwd=PROJECT,
                              capture_output=True, text=True, check=True, timeout=15).stdout.strip().rsplit(":", 1)[-1]
        if not port.isdigit() or not 0 < int(port) <= 65535:
            raise RuntimeError("The local browser port could not be found.")
        fixture["base_url"] = f"http://127.0.0.1:{port}/allfedo/"
        with tempfile.TemporaryDirectory(prefix="allfedo-browser-") as directory:
            path = Path(directory) / "accounts.json"
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "w") as handle:
                json.dump(fixture, handle)
            environment = dict(os.environ, ALLFEDO_BROWSER_ACCOUNTS=str(path))
            subprocess.run(["node", str(PROJECT / "tests" / "browser" / "flow.mjs")],
                           cwd=PROJECT, env=environment, check=True, timeout=600)
    finally:
        terminal('Do ##class(AllfedoBrowserScenario).RemoveFromEnvironment()\nWrite !,"ALLFEDO_BROWSER_OK=1",!', accounts)
        print("Temporary browser logins removed. Saved test records remain in their isolated network.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, StopIteration, subprocess.SubprocessError) as error:
        raise SystemExit(f"Browser checks did not finish: {error}") from None
