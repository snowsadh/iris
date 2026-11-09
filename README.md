# Allfedo

Allfedo helps known kitchens and shelters turn surplus food into agreed pickups and confirmed receipts, with a coordinator handling unresolved work.

**Current stage: working native core; full application in progress.** The food rules, saved commands, AI Hub decision, explicit coordinator send, collection records, and local test email have run on the actual contest image. Signed-in screens and complete recovery paths are still being built. Test partners and quantities are fictional; this is not a field-validated food service.

## Local runtime setup

Requires Docker with Compose and Python 3.10+. Download an accepted AI Hub Community Docker archive from the [official portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). Build `2027.1.0AI.109.0` is accepted; the installer also recognizes the earlier accepted build `2026.3.0AI.154.0`. Use the archive matching the host CPU. Do not publish the licensed image.

Create `.env` from [.env.example](.env.example) if it does not already exist. Put the OpenAI key there locally. Existing credentials must be preserved.

```bash
python3 scripts/iris_runtime.py /path/to/iris-community-2027.1.0AI.109.0-docker.tar.gz --setup
```

The installer checks the archive's build/platform, loads and tags it locally, preserves private settings, and starts IRIS and a test email inbox. It verifies the running image, native version and AI Hub classes. An ignored `compose.override.yaml` selects the image and a separate data volume per build. A short initialization step prepares volume ownership; IRIS itself runs as its normal user.

`--setup` creates the isolated `ALLFEDO` application namespace, compiles source, configures the signed-in web routes, and starts its Production. It stops an existing Allfedo Production before changing configuration or code. It creates no partner accounts and makes no model call. Use `python3 scripts/iris_runtime.py --setup` to apply source changes on the installed runtime.

Prepare six fictional partners for a local walkthrough:

```bash
python3 scripts/demo.py
```

This creates four partner locations and private accounts for two kitchens, two receiving teams, a coordinator, and a collector. Usernames and random passwords are in ignored `.env.demo.json`, readable only by the local file owner. Reruns preserve accounts and history; they do not reset passwords or food records. No food, need, pickup, or model decision is invented by setup.

Local developer endpoints after successful startup:

- Allfedo sign-in: <http://127.0.0.1:52773/allfedo/>
- IRIS Management Portal: <http://127.0.0.1:52773/csp/sys/UtilHome.csp>
- Mailpit test inbox: <http://127.0.0.1:8025>

The services bind to the local machine. Named volumes preserve runtime and inbox data across container replacement. Only ObjectScript, Python, and browser source folders are mounted read-only into IRIS. Private settings and idea notes are not mounted. Port overrides are in `.env.example`.

Repeat the archive and configuration checks:

```bash
python3 -m unittest discover -s tests -v
docker compose config --quiet
python3 scripts/iris_runtime.py --test
```

The first checks cover host-side rules and installer contracts. `--test` runs native commands, shared-capacity races, temporary-lock recovery, persistent-worker cleanup, partner/food confirmation, and signed-in HTTP checks. It creates separate synthetic networks, keeps their records for inspection, and removes its temporary login accounts. It makes no model call. Compose is validated quietly to keep resolved credentials out of output.

## Native workflow

IRIS runs the integration workflow, called a **Production**. A signed-in partner command enters a Business Service. A Business Process routes it to the native AI Hub agent or the saved food-rescue commands. The agent reads only the authorized case and can submit a proposal or ask for review. It cannot reserve food or approve a pickup.

The coordinator sends a separate reviewed plan. IRIS rechecks current food and receiving capacity inside one transaction, saves temporary holds, and queues notification intentions. Recipient acceptance, assigned collection, physical kitchen handoff, and receiving confirmation remain separate events.

Verified on **AI Hub Community `2027.1.0AI.109.0`**, with **Python 3.12.3** inside IRIS. A live `gpt-4.1-mini` proposal passed through the Production, stayed unreserved until the explicit send, and then created a guarded hold. Actual SMTP messages reached the local Mailpit inbox. These checks establish integration behavior, not model quality or real-world rescue outcomes.

## Food invitation rules

The Python module [invitations.py](src/python/allfedo/invitations.py) checks a proposed food split against confirmed records. It checks remaining stock and receiving need across kitchens, changed records, collection windows, units, declared allergens, handling requirements, and source references. Unknown facts require a person to confirm them.

A passing proposal still needs recipient acceptance and collection arrangements. This check does not reserve food. IRIS must recheck the current records inside the transaction that creates the holds.

The current native release accepts whole meal boxes only. It does not infer vehicle fit or travel time. Partners confirm their location, entrance, time zone, food conditions, and packaging. Missing facts remain unknown; changed receiving needs preserve existing promises. Complete shortage/custody resolution and the full browser journey remain release work.

## Project guide

- [Complete product story](doc/PRODUCT.md): people, commitments, physical handoffs, and failure handling.
- [Experience brief](doc/INTERFACE.md): role-specific work, visual cues, and design review requirements.
- [Technical plan](doc/TECHNICAL_PLAN.md): native integration, shared capacity, transactions, retries, and implementation order.
- [Submission checklist](doc/SUBMISSION.md): required work and optional bonuses.
- [Platform research](doc/INFO.md) and [project journey](doc/JOURNEY.md).

Product design starts with real responsibilities: an offer is not a reservation, collection is not receipt, and unresolved food must retain an owner and a next action.

## License and checks

Allfedo source uses the [MIT license](LICENSE). Vendor images retain their own terms. Bundled third-party assets retain their accompanying licenses.

Native and browser checks require the licensed local runtime; a passing host check does not replace them.
