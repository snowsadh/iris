# Allfedo

Allfedo helps known kitchens and shelters turn surplus food into agreed pickups and confirmed receipts, with a coordinator handling unresolved work.

**Current stage: product and technical design.** No live food-rescue service or IRIS workflow has been implemented. The flow sketch's visual design was rejected; it is not the final interface. Example partners and quantities are fictional.

## Local runtime setup

Requires Docker with Compose and Python 3.10+. Download an accepted AI Hub Community Docker archive from the [official portal](https://evaluation.intersystems.com/Eval/early-access/AIHub). Build `2027.1.0AI.109.0` is accepted; the installer also recognizes the earlier accepted build `2026.3.0AI.154.0`. Use the archive matching the host CPU. Do not publish the licensed image.

Create `.env` from [.env.example](.env.example) if it does not already exist. Put the OpenAI key there locally. Existing credentials must be preserved.

```bash
python3 scripts/iris_runtime.py /path/to/iris-community-2027.1.0AI.109.0-docker.tar.gz
```

The installer checks the archive's build/platform, loads and tags it locally, preserves private settings, starts IRIS and a test email inbox, and checks the actual IRIS version and compiled Hub classes. It does not configure or claim a working application or model call.

Local developer endpoints after successful startup:

- IRIS Management Portal: <http://127.0.0.1:52773/csp/sys/UtilHome.csp>
- Mailpit test inbox: <http://127.0.0.1:8025>

The services bind to the local machine. Named volumes preserve runtime and inbox data across container replacement. No source folder or private idea notes are mounted into IRIS. Port overrides are in `.env.example`.

Repeat the archive and configuration checks:

```bash
python3 -m unittest discover -s tests -v
docker compose config --quiet
```

These checks do not simulate native installation, concurrent SQL reservations, or a live Hub call. Native verification remains pending until the licensed archive is available. Compose is validated quietly to keep resolved credentials out of output.

## Project guide

- [Complete product story](doc/PRODUCT.md): people, commitments, physical handoffs, and failure handling.
- [Experience brief](doc/INTERFACE.md): role-specific work, visual cues, and design review requirements.
- [Technical plan](doc/TECHNICAL_PLAN.md): native integration, shared capacity, transactions, retries, and implementation order.
- [Submission checklist](doc/SUBMISSION.md): required work and optional bonuses.
- [Platform research](doc/INFO.md) and [project journey](doc/JOURNEY.md).

Product design starts with real responsibilities: an offer is not a reservation, collection is not receipt, and unresolved food must retain an owner and a next action.

The rejected browser sketch was removed from active code. Its original version is preserved in Git commit `23aa834`. New implementation must use the complete operating model rather than extending that single-case simulation.
