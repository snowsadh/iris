# What has been checked

Checked 9 November 2026 on AI Hub Community **2027.1.0AI.109.0**, with Embedded Python **3.12.3**. Source implementation: [`f6459b6`](https://github.com/snowsadh/iris/commit/f6459b66d5fadecc3311ec643bdf727977211d85). Later documentation and submission assets do not change that implementation.

## Repeat the release checks

Follow [setup](../README.md), then run:

```bash
python3 -m unittest discover -s tests -q
docker compose config --quiet
python3 scripts/iris_runtime.py --test
npm ci
npx playwright install chromium
npm run test:time
npm run test:browser
```

| Check | Observed result |
|---|---|
| Host Python | 45 passed: proposal rules, stock projection and installer contracts. |
| Browser time handling | Four passed, including another device time zone, clock changes and exact source-time preservation. |
| Native integration | All 17 runner groups passed on the real image. |
| Signed-in web requests | Core 65, onward delivery 32 and rejected-food follow-up 29 checks passed. These are included in the native runner. |
| Browser journey | Five independent accounts covering four roles and two receiving teams passed. Temporary logins were removed afterward. |
| Local email | Actual scheduled SMTP delivery reached Mailpit, including Unicode and the handling deadline. |

The native groups cover commands, arithmetic, two-process capacity races, temporary lock recovery, partner facts, persistent workers, changed promises, onward delivery, rejected-food movements, unavailable provider, notification guards and signed-in web requests. A passing host test alone does not establish these runtime results.

The browser records a real 35-box invitation, 30 accepted, 28 handed over and 27 received. It preserves the original promise, requires current kitchen and receiving confirmations, tests physical corrections, and recovers a lost response after reload without duplicating a saved action.

A separate browser case collects 18 boxes once, redirects 15 to one accepted destination and three to another, and records each receipt. It checks capacity for all carried food and prevents the new recipient from opening the previous team's private case. Another case follows two rejected boxes through one return and one disposal; accepted food stays two and the same rejected portions are counted once.

## Fresh installation

Cloned the public branch at `f6459b6` into a separate directory. Reused only the already-loaded, licensed Docker image. Created new application and inbox volumes, used separate local ports and left `OPENAI_API_KEY` empty.

Setup, all 17 native groups, six demo-account sign-ins, dependency installation, four time checks and the full browser journey passed. No development database, private demo account file or provider key was copied. The 3 GB vendor archive was not downloaded again. Actual archive loading and build verification had already succeeded during the main installation.

An earlier isolated SMTP-outage check stopped the test inbox. Delivery remained pending after attempt one, then succeeded on attempt two after the inbox restarted. This establishes bounded retry behavior for that case, not guaranteed external email delivery.

## Actual agent evidence

Two successful paid native planning decisions ran during development. The later saved run, number 20, used **gpt-4.1-mini** through the IRIS Production and native AI Hub. Run numbers include test fixtures and failures; they are not a count of paid calls.

That run read the offer, current needs and collection facts, then submitted a proposal: four tool calls across three model interactions. The native SDK reported **2,743 prompt tokens, 278 completion tokens and 5,074 ms of model time** for the session. Its final response separately reported 1,370 prompt and 74 completion tokens. These are different scopes; do not add them together.

Planning created no holds. A separate coordinator command then saved the reviewed invitations. Model credentials remained server-side. No model was trained or fine-tuned. This synthetic case proves the native integration; it does not measure planning quality, general accuracy or expected performance. No exact monetary cost was recorded.

Ordinary native and browser checks make no paid model call. Browser plans are manual. Provider-failure checks verify a visible failure, safe request replay, unchanged reservations and the checked manual fallback.

## Limits and participant checks

There have been no partner interviews, physical rescue trials or independent human usability sessions. Scripted physical reports describe fictional events. Screenshots are actual app screens with fictional data. The app does not certify food condition, infer travel time or prove how many people were fed.

The local test inbox is not live partner messaging. Public hosting, real partner onboarding and operating procedures remain separate work. Only the tested x64 build is claimed; archive recognition for another accepted build is not a claim that its complete application journey ran.

The [walkthrough](WALKTHROUGH.md) includes participant checks and recording directions. Contest listing approval, contest association, published articles and a demo video are separate deliverables; passing software checks does not establish their completion.
