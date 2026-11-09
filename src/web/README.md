# Browser app

IRIS serves this folder at `/allfedo/`. The browser uses standard JavaScript modules. There is no frontend build step and no production package dependency.

Sign-in belongs to IRIS’s own password form. The app reads the signed-in person and role from `/allfedo/api/session`. It never asks JavaScript to collect a password or choose a role.

## Find the code

- `app.js`: navigation, loading saved records and showing command outcomes.
- `api.js`: authenticated requests and safe recovery after a lost response.
- `render.js`: safe text and conditional-child rendering, shared forms and useful handoff drawings.
- `time.js`: site-local dates, clock changes and explicit time conversion.
- `views/`: kitchen offers, receiving needs, collections, coordinator review and partner locations.
- `styles.css`: the service’s responsive layout and visual rules.

Food facts, commitments, trips and receipts live in IRIS. The browser does not keep a second food ledger. It stores only an unfinished command’s request ID, action, payload and start time in session storage, scoped to the signed-in account. It saves that recovery reference before sending. A reload can check the same request instead of creating a duplicate. Known outcomes and sign-out clear the reference.

Open cases check for saved updates every 15 seconds and when the window becomes active. Unsaved form input is kept; changed records prompt a fresh read before a stale submission.

Collection forms use the recorded site’s time zone. A repeated local clock reading needs an explicit choice. Unknown dates remain blank. Allergen inputs distinguish present, checked-absent and unassessed facts; users can add labels beyond the common choices.

## Check it

Use Node.js 20 or newer for these development checks. The served app needs no Node.js runtime.

```bash
npm ci
npm run test:time
npx playwright install chromium
ALLFEDO_BROWSER_ACCOUNTS=/path/to/private-test-accounts.json npm run test:browser
```

The private account file needs `accounts.coordinator`, `accounts.kitchen`, `accounts.recipient` and `accounts.collector`. Each contains `username`, `password` and `actor_id`. Optional `base_url` defaults to `http://127.0.0.1:52773/allfedo/`. Never commit this file. The local demo setup supplies invited accounts separately.

The browser journey uses real native sessions and saved commands. Each full run needs a fresh isolated four-role fixture because its intentional custody discrepancy remains open; the runner never erases it to reuse a collector. Run it only against an isolated test network: it creates food and receiving records and keeps them for inspection. It uses a manual invitation plan and makes no paid model call. Screenshots go to `/tmp/allfedo-browser-check`; override with `ALLFEDO_BROWSER_OUTPUT`. An existing Chromium binary can be selected with `PLAYWRIGHT_CHROMIUM_EXECUTABLE`.

The time checks run without IRIS. Browser checks require the running, configured application. Neither proves food safety, real transport capacity or a successful physical rescue.

Public Sans is bundled under its [Open Font License](assets/OFL.txt).
