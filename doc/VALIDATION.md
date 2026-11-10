# What has been checked

Checked 9–10 November 2026 on AI Hub Community **2027.1.0AI.109.0**, with Embedded Python **3.12.3**. Provider settings and one-command setup were checked from clean source at [`2994291`](https://github.com/snowsadh/iris/commit/2994291cb6f1a072ee5c157bf0371826863d8f74). Earlier baseline checks are identified separately below.

## Repeat the release checks

Follow [setup](../README.md), then run:

```bash
python3 -m unittest discover -s tests -q
docker compose config --quiet
python3 scripts/iris_runtime.py --test
npm ci
npx playwright install chromium
npm run test:time
npm run test:transport
npm run test:browser
python3 scripts/demo.py
npm run test:settings
npm run test:demo
```

| Check | Observed result |
|---|---|
| Host Python | 50 passed: proposal rules, stock projection, installer contracts and private setup settings. |
| Browser time handling | Four passed, including another device time zone, clock changes and exact source-time preservation. |
| Browser report transport | One passed: fresh server time for a just-now report, exact retry after a lost response, and unchanged explicit event time. |
| Native integration | All 18 runner groups passed on the real image. |
| Signed-in web requests | Core, onward delivery and rejected-food follow-up scenarios passed, including actual wallet deletion after default selection and logout. These are included in the native runner. |
| Browser journey | Five independent accounts covering four roles and two receiving teams passed. Temporary logins were removed afterward. |
| Settings browser | Real wallet save with a fake key, session isolation, role checks, removal and widths from 320 to 1440 pixels passed. No key appeared in the read response or browser storage. |
| Local email | Actual scheduled SMTP delivery reached Mailpit, including Unicode and the handling deadline. |

The native groups cover commands, arithmetic, two-process capacity races, temporary lock recovery, partner facts, persistent workers, changed promises, onward delivery, rejected-food movements, provider settings and failure, notification guards and signed-in web requests. Settings checks use fake keys: ownership, expiry, native provider construction, the shared default allowance, personal-key bypass and the 150-character model boundary. A passing host test alone does not establish these runtime results.

The browser records a real 35-box invitation, 30 accepted, 28 handed over and 27 received. It preserves the original promise, requires current kitchen and receiving confirmations, tests physical corrections, and recovers a lost response after reload without duplicating a saved action.

The optional demo launcher is checked separately with `npm run test:demo`, after preparing the local demo accounts. This opens six native sessions without a model call, checks their identities and distinct window titles, and confirms that signing one out leaves another signed in. It uses `ALLFEDO_BASE_URL` if the local web port differs.

A repeated browser run exposed a just-now handoff dated about 0.8 seconds before the collector agreement by the browser's estimated clock. Just-now physical reports now read a fresh server time before sending. The resulting timestamp is saved with the recovery reference; retries reuse it. Explicit earlier times and native agreement checks remain unchanged.

A separate browser case collects 18 boxes once, redirects 15 to one accepted destination and three to another, and records each receipt. It checks capacity for all carried food and prevents the new recipient from opening the previous team's private case. Another case follows two rejected boxes through one return and one disposal; accepted food stays two and the same rejected portions are counted once.

## Fresh installation

On 10 November, exported only tracked source at `2994291` into a separate directory. Reused the licensed local image with an isolated Compose project, new application and inbox volumes, and separate ports. No private files or provider key were copied. Ran `python3 scripts/start.py` and selected manual planning with an empty key.

Setup, all 18 native groups, dependency installation, the complete browser journey, Settings checks and six-account demo checks passed. Running setup again with closed input needed no prompts, preserved the generated credentials and saved offer/collection counts, and left all six sign-ins working after container recreation. Both generated private files had owner-only permissions. No provider call was made.

The earlier public baseline `7cc3e48` also passed a fresh installation, all 17 then-existing native groups, demo sign-ins, dependency installation, four time checks and the full browser journey. Both installations reused the licensed image; the 3 GB vendor archive was not downloaded again. Actual archive loading and build verification had succeeded during the main installation.

An earlier isolated SMTP-outage check stopped the test inbox. Delivery remained pending after attempt one, then succeeded on attempt two after the inbox restarted. This establishes bounded retry behavior for that case, not guaranteed external email delivery.

A later branch switch replaced bind-mounted source folders. Setup previously accepted the empty mounted tree while compiled native code remained available. The installer now compares mounted runtime-file hashes with the checkout before stopping workers or compiling. The actual stale mount was refused. Recreating the container preserved its data volume; all 17 native groups and the full browser journey then passed with the updated wordmark. Browser checks explicitly decode the authenticated brand image.

On 10 November, a Docker restart revealed that the healthy IRIS server had not resumed Allfedo’s Production. Setup now enables native Production auto-start. A real container restart resumed it automatically; the complete native checks then passed. This is separate from the vendor startup warning below.

## Actual agent evidence

Four successful paid native planning decisions ran during development. The earlier saved run, number 20, used **gpt-4.1-mini** through the IRIS Production and native AI Hub. Run numbers include test fixtures and failures; they are not a count of paid calls.

That run read the offer, current needs and collection facts, then submitted a proposal: four tool calls across three model interactions. The native SDK reported **2,743 prompt tokens, 278 completion tokens and 5,074 ms of model time** for the session. Its final response separately reported 1,370 prompt and 74 completion tokens. These are different scopes; do not add them together.

Planning created no holds. A separate coordinator command then saved the reviewed invitations. Model credentials remained server-side. No model was trained or fine-tuned. This synthetic case proves the native integration; it does not measure planning quality, general accuracy or expected performance. No exact monetary cost was recorded.

Two later browser-driven decisions, saved runs **41 and 42**, used OpenAI `gpt-4.1-mini` through personal and default connections respectively. The personal key was entered through the real Settings form; both decisions reached `SubmitProposal` through the Production and native AI Hub, saved the selected connection source and created no holds. Live planning with OpenRouter and Gemini is not verified.

To repeat the two paid browser decisions deliberately, configure a local key and run `python3 scripts/browser_test.py --live-ai`. This creates separate test accounts, runs the ordinary journey, then requests personal and default plans. It is never included in `npm run test:browser`.

Ordinary native and browser checks make no paid model call. Browser plans are manual. Provider-failure checks verify a visible failure, safe request replay, unchanged reservations and the checked manual fallback.

## Provider compatibility

Checked official documentation and the installed native request path on 10 November 2026. `gemini-3.8-flash` has [no announced shutdown date](https://ai.google.dev/gemini-api/docs/deprecations#gemini-3-models); Google's documented route remains `v1beta/openai/chat/completions`. OpenRouter still supports `api/v1/chat/completions`, and its [current catalog](https://openrouter.ai/api/v1/models/openai/gpt-4.1-mini/endpoints) lists the suggested `openai/gpt-4.1-mini` with tool support. See [Google's compatibility guide](https://ai.google.dev/gemini-api/docs/openai) and [OpenRouter's API reference](https://openrouter.ai/docs/api_reference/overview).

A separate, one-off protocol check ran both native providers against a loopback HTTPS fixture using fake keys, a temporary trusted certificate authority and enabled certificate validation. Nothing was forwarded to either service. Each provider completed three request rounds with Allfedo's six actual tools: two parallel reads, a further read, then a synthetic final response. Assertions checked the exact URL path, Bearer authentication, selected model, 1,200-token limit, tool schemas on every round, matching result IDs and grouped parallel results. No deprecated `functions` or `function_call` request fields were sent.

Gemini also preserved both synthetic `extra_content.google.thought_signature` values on later requests. This metadata lets Google continue a tool-calling turn; omitting it can cause a validation error. The shape matches [Google's own compatibility code](https://github.com/google/adk-java/blob/main/core/src/main/java/com/google/adk/models/chat/ChatCompletionsRequest.java) and its [signature requirements](https://ai.google.dev/gemini-api/docs/thought-signatures). No application change was needed. This fixture checks request construction and replay, not real account access, billing, provider availability or model quality. It is separate from the ordinary 18-group runner.

## Verification limits

There have been no partner interviews, physical rescue trials or independent human usability sessions. Scripted physical reports describe fictional events. Screenshots are actual app screens with fictional data. The app does not certify food condition, infer travel time or prove how many people were fed.

The local test inbox is not live partner messaging. Public hosting, real partner onboarding and operating procedures remain separate work. Only the tested x64 build is claimed; archive recognition for another accepted build is not a claim that its complete application journey ran.

The [sample journey](DEMO.md) explains how to explore the workflow. Scripted browser checks do not replace independent human usability testing or operational validation.

The downloaded image also logs a missing `SYS.ICM.Sharding` method at startup. The image identifier matched its SHA-256 blob in the original archive. A separate container without Allfedo reproduced the error; fresh durable storage and a restart reproduced it too. Those controls passed the unchanged vendor health probe.

Our application container temporarily reported a system alert, then returned to a warning and healthy probe without an application change. The application checks passed in that runtime. The health-state difference remains unexplained; the [upstream report](https://github.com/intersystems-community/ai-hub-eap/issues/48) does not claim that its full cause has been established.
