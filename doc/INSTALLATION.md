# Installation and troubleshooting

The [README](../README.md) gives the shortest setup. This page explains the runtime, preserved data and common failures.

## Prepare the runtime

Use Docker with Compose and Python 3.10 or newer. The complete application has been tested on x64 AI Hub Community `2027.1.0AI.109.0`, with Python 3.12.3 inside IRIS. The installer also recognizes accepted build `2026.3.0AI.154.0`; that recognition is not a claim that its complete application journey was tested.

Download the licensed archive matching the host CPU from the [official portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). Do not publish the vendor image. Create `.env` from `.env.example`, preserving existing settings. Set your OpenAI key locally if using the agent.

```bash
python3 scripts/iris_runtime.py /path/to/iris-community-2027.1.0AI.109.0-docker.tar.gz --setup
```

The installer checks the archive's build and platform, loads and tags it locally, starts the containers, then checks the actual native version and AI Hub classes. An ignored `compose.override.yaml` selects the image and a separate data volume per build. A short initialization step prepares volume ownership; IRIS runs as its normal user.

Setup creates separate code and data databases in the `ALLFEDO` namespace, compiles source, configures signed-in web routes and starts `Allfedo.Production`. It creates no partner accounts and makes no model call. Only ObjectScript, Python and browser source folders are mounted read-only; private files are not mounted.

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

All default ports bind to loopback. IRIS Portal is at <http://127.0.0.1:52773/csp/sys/UtilHome.csp>. Public deployment and real partner email need separate operator configuration and validation.
