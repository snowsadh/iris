# Browser app

IRIS serves this folder at `/allfedo/`. The browser uses standard JavaScript modules. There is no frontend build step and no production package dependency.

Sign-in belongs to IRIS’s own password form. The app reads the signed-in person and role from `/allfedo/api/session`. It never asks JavaScript to collect a password or choose a role.

## Find the code

- `app.js`: navigation, loading saved records and showing command outcomes.
- `api.js`: authenticated requests and safe recovery after a lost response.
- `render.js`: safe text and conditional-child rendering, saved facts and handoff drawings.
- `forms.js`: shared input, local-time entry, allergen labels and save/retry behavior.
- `time.js`: site-local dates, clock changes and explicit time conversion.
- `views/`: kitchen offers, receiving needs, invitation/trip flow, physical reports, commitment changes, coordinator review, onward delivery and partner locations.
- `styles.css`: the service’s responsive layout and visual rules.

Food facts, commitments, trips and receipts live in IRIS. The browser does not keep a second food ledger. It stores only an unfinished command’s request ID, action, payload and start time in session storage, scoped to the signed-in account. It saves that recovery reference before sending. A reload can check the same request instead of creating a duplicate. Known outcomes and sign-out clear the reference.

Open cases check for saved updates every 15 seconds and when the window becomes active. Unsaved form input is kept; changed records prompt a fresh read before a stale submission.

Receiving needs state when the door opens and closes. Collection forms use the recorded site’s time zone. A repeated local clock reading needs an explicit choice. Unknown dates remain blank. A quantity-only correction retains the original physical timestamp’s full precision. Allergen inputs distinguish present, checked-absent and unassessed facts; users can add labels beyond the common choices.

## Check it

Use Node.js 20 or newer for these development checks. The served app needs no Node.js runtime.

```bash
npm ci
npm run test:time
npm run test:transport
npx playwright install chromium
npm run test:browser
```

The browser runner creates five temporary native logins covering four roles in a fresh isolated network. It runs the real kitchen, coordinator, receiving and collector journey, then removes those logins. Saved test records remain for inspection. It records a partial pickup and receipt, then requires both partners to agree a smaller commitment backed by a real kitchen count and a known rejected box. Earlier promises and physical reports remain in the record. Repeated runs use fresh networks instead of erasing history. It uses a manual invitation plan and makes no paid model call.

Screenshots go to `/tmp/allfedo-browser-check`; override with `ALLFEDO_BROWSER_OUTPUT`. An existing Chromium binary can be selected with `PLAYWRIGHT_CHROMIUM_EXECUTABLE`.

For an already provisioned isolated test network, run the journey directly:

```bash
ALLFEDO_BROWSER_ACCOUNTS=/path/to/private-test-accounts.json node tests/browser/flow.mjs
```

That private file needs `accounts.coordinator`, `accounts.kitchen`, `accounts.recipient`, `accounts.collector` and `accounts.recipient2`. Each contains `username`, `password` and `actor_id`. Optional `base_url` defaults to `http://127.0.0.1:52773/allfedo/`. Use a fresh fixture for each full run. Never commit this file. The local demo setup supplies invited accounts separately.

The time checks run without IRIS. Browser checks require the running, configured application. Neither proves food safety, real transport capacity or a successful physical rescue.

Public Sans is bundled under its [Open Font License](assets/OFL.txt).

A changed promise never explains missing food. Physical reports use their actual occurrence time; late reports remain possible after current instructions change. Corrections keep the original report visible. Returned food stays quarantined. Only the native record’s explicit permission can expose a correction action.

Onward delivery uses the collector’s current count, location and holding report. A new receiving invitation reserves already-carried food. Only that receiving team can accept it, and the collector must separately agree the new arrival. Linked cases show transferred custody without recording another kitchen pickup. The whole carried load comes from the native helper; the browser never adds parent and child handoff totals. Recipient views cannot open the other team’s private case or read its location report.
