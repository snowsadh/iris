# Installation and troubleshooting

The [README](../README.md) gives the shortest setup. This page explains the runtime, preserved data and common failures.

## Prepare the runtime

Use Docker with Compose and Python 3.10 or newer. The complete application has been tested on x64 AI Hub Community `2027.1.0AI.109.0`, with Python 3.12.3 inside IRIS. The installer also recognizes accepted build `2026.3.0AI.154.0`; that recognition is not a claim that its complete application journey was tested.

Download the licensed archive matching the host CPU from the [official portal](https://evaluation.intersystems.com/Eval/early-access/AIHub), then run:

```bash
python3 scripts/start.py
```

The helper asks for your provider, hidden key and optional model ID. Leave the key empty for manual planning. Existing private settings are reused. It selects an already installed Allfedo image, finds the archive in Downloads or asks for its path. You can also supply the archive directly:

```bash
python3 scripts/start.py /path/to/iris-community-2027.1.0AI.109.0-docker.tar.gz
```

It starts the services, configures the app, creates the fictional partners and opens the sign-in page. The generated `.env` is ignored and readable only by its local owner. Do not publish the vendor image or share a provider key with a local installation.

For automated or step-by-step installation, prepare `.env` from `.env.example`, then run the lower-level installer:

```bash
python3 scripts/iris_runtime.py /path/to/iris-community-2027.1.0AI.109.0-docker.tar.gz --setup
```

The installer checks the archive's build and platform, loads and tags it locally, starts the containers, then checks the actual native version and AI Hub classes. An ignored `compose.override.yaml` selects the image and a separate data volume per build. A short initialization step prepares volume ownership; IRIS runs as its normal user.

Setup creates separate code and data databases in the `ALLFEDO` namespace, compiles source, configures signed-in web routes and starts `Allfedo.Production`. It also enables native auto-start so the Production resumes after IRIS restarts. This lower-level step creates no partner accounts and makes no model call. Only ObjectScript, Python and browser source folders are mounted read-only; private files are not mounted.

## AI connections

`AI_PROVIDER` accepts `openai`, `openrouter` or `gemini`. `AI_API_KEY` holds the matching key. Leave `AI_MODEL` empty to use the suggested model, or choose a model in your account that supports tool calls. Existing `OPENAI_API_KEY` and `OPENAI_MODEL` settings remain supported for OpenAI.

OpenAI with `gpt-4.1-mini` is the live-tested baseline. OpenRouter and Gemini use their native AI Hub providers. Their actual request formats and repeated tool calls passed a local test-server check, including Gemini's required signature metadata. Live calls to those two services remain untested; a model must also be available to the supplied account. See the [compatibility check](VALIDATION.md#provider-compatibility) and provider guides for [OpenRouter model IDs](https://openrouter.ai/docs/quickstart) and [Gemini's compatible API](https://ai.google.dev/gemini-api/docs/openai).

In the app, **Settings** lets a coordinator keep the workspace default or enter a personal provider, model and key. Personal keys live in IRIS's secure wallet. They are scoped to that signed-in browser session, never returned by the API and never placed in command recovery storage or Production messages. They expire after one hour; signing out or choosing the default removes them. Expired entries are unusable immediately and are cleaned up on subsequent settings access.

An expired or failed personal connection never silently switches to the default key. Rechecking an earlier saved planning request returns that request's result without another provider call.

`AI_DAILY_LIMIT` defaults to 50 planning attempts per UTC day across the workspace default key. Personal-key calls do not consume that allowance. Each planning attempt also retains the existing tool-round, token and time bounds. This is an attempt limit, not a currency budget; use the provider's project spend controls as well.

Changing environment settings requires refreshing the containers. Rerun `python3 scripts/start.py`, or recreate IRIS and rerun the lower-level setup. Named volumes preserve saved data.

For a hosted judging demo, configure the default key on the server so judges can start immediately. Serve it over HTTPS, keep management ports private and keep the key out of downloaded source. Public hosting is a separate deployment step; the supplied Compose setup binds to the local machine.

## Create demonstration accounts

```bash
python3 scripts/demo.py
```

This creates four fictional locations and accounts for two kitchens, two receiving teams, a coordinator and a collector. `.env.demo.json` contains generated credentials and is readable only by its local owner. It is ignored by Git. Reruns preserve passwords and history; they do not reset food records. Follow the [sample collection](DEMO.md).

## Apply source changes

```bash
python3 scripts/iris_runtime.py --setup
```

Setup stops the existing Allfedo Production before compiling, then restarts it. A persistent worker can otherwise retain old loaded code even after compilation succeeds. Named volumes retain application and inbox data across container replacement. Do not remove volumes to solve an ordinary application error.

## Common problems

| Symptom | Check |
|---|---|
| Archive refused | Use an accepted AI Hub Community build and the correct host CPU. An ordinary IRIS image does not supply the tested native AI Hub interfaces. |
| Port already in use | Change ports in `.env`; update `ALLFEDO_PUBLIC_URL` to match the browser port. |
| Sign-in works but membership is missing | Use a generated partner account. An operator needs both a native IRIS account and an active Allfedo Actor record. |
| Suggestion fails | Check the server's provider key and model access. Read the failed attempt; request checking does not silently start another paid run. Use checked manual planning if needed. |
| Proposal needs review | Confirm current food, allergens, handling, receiving hours and total need. Unknown facts are not treated as safe defaults. |
| Email appears missing | Open Mailpit at the configured port. Check the case's notification state; server acceptance is not a recipient reply. |
| Browser checks cannot start | Install Node.js 20+, run `npm ci` and `npx playwright install chromium`. See the [browser guide](../src/web/README.md) for an existing binary. |
| Saved data appears different after changing builds | Each accepted build uses a separate data volume. Select the intended build rather than copying incompatible runtime data. |
| Setup reports a source mismatch after switching branches | Run `docker compose up -d --force-recreate iris`, then rerun setup. Docker may still hold the replaced source folders. Recreating the container preserves its named data volume. |

All default ports bind to loopback. IRIS Portal is at <http://127.0.0.1:52773/csp/sys/UtilHome.csp>. Public deployment and real partner email need separate operator configuration and validation.

## Build 109 startup message

The official x64 Community image can log `<METHOD DOES NOT EXIST>Sharding+2^STU *Sharding,SYS.ICM` during startup. It reproduced without Allfedo installed, using the same image identifier as the downloaded archive.

Clean image and durable-volume controls passed their health checks despite that message. Our recreated development container briefly reported `alert`, then IRIS changed it to `warn` and Docker reported healthy without an application change. The controls do not establish the cause of that temporary health difference.

The [upstream report](https://github.com/intersystems-community/ai-hub-eap/issues/48) records the conditions and observations. Keep the vendor health check enabled. Inspect the actual message in `/durable/iris/mgr/messages.log` before treating a new alert as the same case.
