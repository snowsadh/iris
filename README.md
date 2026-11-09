# Allfedo

Allfedo helps known kitchens and shelters turn surplus food into agreed pickups and confirmed receipts, with a coordinator handling unresolved work.

**Working contest release on AI Hub Community `2027.1.0AI.109.0`.** The native integration, four-role browser journey, shared-capacity checks, changed promises, onward delivery, returns and disposal have run on the actual image. Test partners and physical events are fictional; no field rescue is claimed.

A kitchen has 40 extra meal boxes. A shelter needs 30. Allfedo helps them agree a quantity, name a collector, confirm the trip, record the kitchen handoff and count what arrived. If fewer boxes arrive or the door is closed, the case keeps a responsible person and a concrete next action.

![Coordinator reviewing invitations before sending](doc/assets/coordinator-review.png)

Actual signed-in screen with fictional test data. This screenshot shows a checked manual plan; it is not evidence of a live model call. [Mobile onward-delivery screen](doc/assets/onward-delivery.png).

## Local runtime setup

Requires Docker with Compose and Python 3.10+. Download an accepted AI Hub Community Docker archive from the [official portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). Build `2027.1.0AI.109.0` is accepted; the installer also recognizes the earlier accepted build `2026.3.0AI.154.0`. Use the archive matching the host CPU. Do not publish the licensed image.

Create `.env` from [.env.example](.env.example) if it does not already exist. Set `OPENAI_API_KEY` locally and keep that file private. `OPENAI_MODEL` defaults to the verified `gpt-4.1-mini`. The coordinator's **Get a planning suggestion** action makes a paid provider call. Setup and ordinary tests do not. Without a key, checked manual planning remains available; it does not demonstrate the required agent decision. Preserve existing credentials.

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

The first checks cover host-side rules and installer contracts. `--test` runs 17 groups covering native commands, shared-capacity races, temporary-lock recovery, persistent workers, physical reports, redirection, failed model access and actual SMTP delivery. Its signed-in HTTP checks cover all four roles. It creates separate synthetic networks, keeps records for inspection, and removes temporary login accounts. It makes no paid model call. Compose is validated quietly to keep resolved credentials out of output.

For browser checks, install Node.js 20 or newer:

```bash
npm ci
npx playwright install chromium
npm run test:time
npm run test:browser
```

The browser journey creates five private test accounts covering four roles. It signs into the real app and follows invitations, partial handoffs and receipts, changed promises, corrections, onward delivery, rejected-food returns and disposal. Lost-response checks reload the page and recover one saved action. The runner removes its logins afterward and retains isolated case history. It uses manual plans and makes no model call. Screenshots go to `/tmp/allfedo-browser-check`. See the [browser guide](src/web/README.md) for an existing browser binary or separately prepared accounts.

## Native workflow

IRIS runs the integration workflow, called a **Production**. A signed-in partner command enters a Business Service. A Business Process routes it to the native AI Hub agent or the saved food-rescue commands. The agent reads only the authorized case and can submit a proposal or ask for review. It cannot reserve food or approve a pickup.

The coordinator sends a separate reviewed plan. IRIS rechecks current food and receiving capacity inside one transaction, saves temporary holds, and queues notification intentions. Recipient acceptance, assigned collection, physical kitchen handoff, and receiving confirmation remain separate events.

Verified on **AI Hub Community `2027.1.0AI.109.0`**, with **Python 3.12.3** inside IRIS. A live `gpt-4.1-mini` proposal passed through the Production, stayed unreserved until the explicit send, and then created a guarded hold. Actual SMTP messages reached the local Mailpit inbox. These checks establish integration behavior, not model quality or real-world rescue outcomes.

## Food invitation rules

The Python module [invitations.py](src/python/allfedo/invitations.py) checks a proposed food split against confirmed records. It checks remaining stock and receiving need across kitchens, changed records, collection windows, units, declared allergens, handling requirements, and source references. Unknown facts require a person to confirm them.

A passing proposal still needs recipient acceptance and collection arrangements. This check does not reserve food. IRIS must recheck the current records inside the transaction that creates the holds.

The release accepts whole meal boxes only. It does not infer vehicle fit or travel time. Partners confirm their location, entrance, time zone, food conditions and packaging. Missing facts remain unknown; changed receiving needs preserve existing promises.

When plans change, the original ticket stays visible. A smaller promise requires the relevant people to confirm current facts. A new destination needs fresh recipient acceptance and collector agreement, without recording a second kitchen pickup. Rejected food can move through a linked return or disposal without being counted twice. Returned food stays quarantined. Actual reports can remain recorded with a visible mismatch; a mismatch does not authorize another unsafe action.

The app is intended for a known local partner network. Public signup, route optimization, automatic food-safety certification and production hosting are outside this release. Email goes to the local Mailpit test inbox. Human handling procedures and partner validation are still needed before real operation.

## Project guide

- [Complete product story](doc/PRODUCT.md): people, commitments, physical handoffs, and failure handling.
- [Walkthrough and recording guide](doc/WALKTHROUGH.md): prepare the fictional partners, follow a complete case, record the demo, and perform human checks.
- [Experience brief](doc/INTERFACE.md): role-specific work, visual cues, and design review requirements.
- [How it works](doc/TECHNICAL_PLAN.md): native integration, shared capacity, transactions and retries.
- [Partner API](doc/API.md): connect a known partner system through authenticated reads and commands.
- [Validation record](doc/VALIDATION.md): actual checks, measured agent usage and their limits.
- [Submission checklist](doc/SUBMISSION.md): required work and optional bonuses.
- [Platform research](doc/INFO.md) and [project journey](doc/JOURNEY.md).

Product design starts with real responsibilities: an offer is not a reservation, collection is not receipt, and unresolved food must retain an owner and a next action.

## License and checks

Allfedo source uses the [MIT license](LICENSE). Vendor images retain their own terms. Bundled third-party assets retain their accompanying licenses.

Native and browser checks require the licensed local runtime; a passing host check does not replace them.

The implemented technology-bonus evidence is Docker and useful Embedded Python inside IRIS. Bonus awards are the organizers' decision. The video and Community article can be added separately; this README and the walkthrough provide the working-app description.

Author: [Snow Sadh on Open Exchange](https://openexchange.intersystems.com/user/snow%2520sadh/AEXFstiBwfewHtVmKbTfiU73Vc).
