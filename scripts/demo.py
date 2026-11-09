"""Prepare fictional local partners and verify their native login, without public passwords."""

from __future__ import annotations

import http.cookiejar
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import tempfile
import urllib.parse
import urllib.request


PROJECT = Path(__file__).resolve().parents[1]
ACCOUNTS = PROJECT / ".env.demo.json"
PROFILES = ("northside", "harbor", "riverside", "bridge", "coordinator", "collector")
COMPOSE = ["docker", "compose", "--file", str(PROJECT / "compose.yaml"),
           "--file", str(PROJECT / "compose.override.yaml")]


def native(method: str, config: dict | None = None) -> dict:
    environment = dict(os.environ)
    command = COMPOSE + ["exec", "-T"]
    if config is not None:
        environment["ALLFEDO_DEMO_CONFIG"] = json.dumps(config)
        command += ["--env", "ALLFEDO_DEMO_CONFIG"]
    command += ["iris", "iris", "session", "IRIS", "-U", "ALLFEDO"]
    script = ('Try { Set result=##class(Allfedo.Demo).' + method +
              '() Write !,"ALLFEDO_DEMO_RESULT=",result,! } Catch error { Write !,"ALLFEDO_DEMO_ERROR=Setup could not run. Prepare the native runtime first.",! }\nHalt\n')
    process = subprocess.run(command, cwd=PROJECT, env=environment, input=script,
                             text=True, capture_output=True, timeout=90)
    match = re.search(r"(?m)^ALLFEDO_DEMO_RESULT=(\{[^\r\n]*\})\r?$", process.stdout)
    if process.returncode or not match:
        raise RuntimeError("Native demo setup could not run. Complete the local runtime setup first.")
    result = json.loads(match[1])
    if not result.get("ok"):
        raise RuntimeError(result.get("error", {}).get("message", "Demo setup could not finish."))
    return result


def configuration() -> dict:
    if ACCOUNTS.is_symlink():
        raise ValueError("The private demo account file must not be a link.")
    if ACCOUNTS.exists():
        os.chmod(ACCOUNTS, 0o600)
        config = json.loads(ACCOUNTS.read_text())
        if not isinstance(config, dict) or set(config) != {"version", "network_id", "accounts"} or type(config.get("version")) is not int or config["version"] != 1:
            raise ValueError("The private demo account file is invalid. Restore its original contents.")
        network = config["network_id"]
        if not isinstance(network, str) or not re.fullmatch(r"allfedo-demo-[a-f0-9]{12}", network):
            raise ValueError("The private demo network ID is invalid.")
        accounts = config["accounts"]
        if not isinstance(accounts, dict) or set(accounts) != set(PROFILES):
            raise ValueError("The private demo account file needs its six known profiles.")
        for key, account in accounts.items():
            if not isinstance(account, dict) or set(account) != {"username", "password"} or account["username"] != network + "-" + key:
                raise ValueError("A private demo account identity is invalid.")
            if not isinstance(account["password"], str) or not 24 <= len(account["password"]) <= 200:
                raise ValueError("A private demo password is invalid.")
        return config
    if native("Status").get("provisioned"):
        raise ValueError("A local demo already exists. Restore .env.demo.json; setup will not reset its passwords or history.")
    network = "allfedo-demo-" + secrets.token_hex(6)
    config = {"version": 1, "network_id": network,
              "accounts": {key: {"username": network + "-" + key, "password": secrets.token_urlsafe(32) + "9!aA"} for key in PROFILES}}
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=PROJECT, prefix=".env.demo.", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(json.dumps(config, indent=2) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        # A concurrent installer cannot replace an already-created private account file.
        os.link(temporary, ACCOUNTS)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return config


class LoginForm(HTMLParser):
    def __init__(self):
        super().__init__()
        self.action = ""
        self.hidden = {}

    def handle_starttag(self, tag, attributes):
        values = dict(attributes)
        if tag == "form":
            self.action = values.get("action", "")
        if tag == "input" and values.get("type", "").lower() == "hidden" and values.get("name"):
            self.hidden[values["name"]] = values.get("value", "")


def browser_url() -> str:
    process = subprocess.run(COMPOSE + ["port", "iris", "52773"], cwd=PROJECT,
                             capture_output=True, text=True, check=True, timeout=15)
    port = process.stdout.strip().rsplit(":", 1)[-1]
    if not port.isdigit() or not 0 < int(port) <= 65535:
        raise RuntimeError("The local IRIS web port could not be found.")
    return f"http://127.0.0.1:{port}/allfedo/"


def verify_login(url: str, config: dict) -> None:
    for key, account in config["accounts"].items():
        browser = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        with browser.open(url, timeout=20) as page:
            form = LoginForm()
            form.feed(page.read().decode("utf-8"))
        target = urllib.parse.urljoin(url, form.action)
        if urllib.parse.urlsplit(target)[:2] != urllib.parse.urlsplit(url)[:2]:
            raise RuntimeError("The native login form changed origin; no credentials were sent.")
        fields = dict(form.hidden, IRISUsername=account["username"], IRISPassword=account["password"])
        call = urllib.request.Request(target, data=urllib.parse.urlencode(fields).encode(),
                headers={"Content-Type": "application/x-www-form-urlencoded",
                         "Origin": urllib.parse.urlsplit(url).scheme + "://" + urllib.parse.urlsplit(url).netloc})
        try:
            with browser.open(call, timeout=20) as page:
                page.read()
            with browser.open(url + "api/session", timeout=20) as response:
                session = json.load(response)
            if session.get("user", {}).get("network_id") != config["network_id"]:
                raise RuntimeError("The demo account opened a different network.")
            if session.get("user", {}).get("demo") is not True:
                raise RuntimeError("The demo session did not identify its fictional data.")
        except (OSError, ValueError):
            raise RuntimeError(f"Native login could not be verified for the {key} demo profile.") from None
        finally:
            logout = urllib.request.Request(url + "api/logout", data=b"{}",
                        headers={"Content-Type": "application/json", "X-Allfedo-Request": "1"})
            try:
                with browser.open(logout, timeout=10) as response:
                    response.read()
            except OSError:
                pass


def main() -> None:
    try:
        config = configuration()
        result = native("SeedFromEnvironment", config)
        url = browser_url()
        verify_login(url, config)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(f"Demo setup not complete: {error}") from None
    print(f"Allfedo local demo is ready: {result['accounts']} accounts and {result['sites']} fictional partner sites.")
    print(f"Open {url}")
    print(f"Passwords are in {ACCOUNTS}. Keep this ignored file private; reruns preserve its accounts and history.")


if __name__ == "__main__":
    main()
