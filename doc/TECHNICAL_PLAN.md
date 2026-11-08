# Food rescue: implementation plan

Status: design decisions and verification work, not a running backend. The old browser sketch explains one case only. Its visual direction was rejected and must not become the production UI by default.

## 1. What proves the contest fit

Interoperability means information passes between systems and produces a useful action. This entry must use a native IRIS Production: incoming business messages, an AI Hub decision, outgoing requests, and replies that continue the case.

Example: a kitchen submits an offer; a shelter's capacity update and tentative collection message arrive separately; the Hub agent chooses a recipient plan or a question; IRIS holds valid quantities, sends invitations, receives authenticated acceptances, and tracks actual collection and receipt.

OpenAI supplies the model. `%AI.Provider`, `%AI.Agent`, and scoped `%AI.ToolSet` methods run the decision inside IRIS. A browser calling OpenAI while IRIS merely stores rows would not demonstrate the intended native workflow.

Evidence required: a real provider call, its tools and decision, the resulting native business messages, an actual outbound delivery to a test inbox/partner interface, and a reply changing the case. Recorded examples supplement the live path; they do not replace it.

[Contest task](https://openexchange.intersystems.com/contest/49), [reviewed Hub guide](https://github.com/intersystems-community/ai-hub-eap/blob/1cca39afeb069413846c4c31196eed0b731f793a/ObjectScript_SDK_Guide.md).

## 2. Keep the pieces small

| Piece | Receives | Does | Produces |
|---|---|---|---|
| Browser app | The signed-in person's tasks and server state | Collects input; shows pending and confirmed outcomes | Authenticated commands with stable request IDs |
| REST Business Service | Kitchen submissions, partner replies, pickup/receipt commands | Checks identity and input; passes typed messages into the Production | Case requests and recoverable command status |
| Offer process | An offer and current needs | Obtains an agent plan, coordinates review, applies valid holds | Invitations or specific questions |
| AI business operation | A case-scoped snapshot and source records | Calls the Hub agent with narrow tools and bounded runtime | A structured proposal, not a booking |
| Collection process | A specific invitation/reservation | Tracks acceptance, deadlines, custody, receipt, and exceptions | Current collection state and follow-up work |
| Domain methods and IRIS SQL | Verified commands and expected record revisions | Make short, atomic state changes | Saved outcomes, events, and pending notifications |
| Outbound operations | Saved requests to deliver | Send email or call an agreed partner web interface | Delivery result; never inferred recipient acceptance |
| Human Workflow Engine | A specific unresolved question | Assigns a task to an authorized coordinator | A version-bound human decision |

REST is the web interface used by the browser and partner integrations. A request ID identifies one user intention across retries. A revision identifies which version of a record the person or agent saw.

Use two durable process types: offer preparation and collection. Several collections can belong to one offer. Exceptions stay attached to those cases; no separate orchestration platform is needed.

IRIS is the authoritative store. Browser storage may hold drafts, not shared stock or final reservations. No second application database, external agent framework, or separate queue service is needed for the initial build.

For development, a local Mailpit inbox receives actual test emails. A real deployment supplies its own email server settings. Partner web callbacks are optional integrations, not a reason to invent a fake external system just for the architecture diagram.

[REST integration](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=EREST_business_service), [email operation](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EEMA_outbound), [Mailpit](https://mailpit.axllent.org/docs/install/docker/).

## 3. Records must describe more than one ideal case

| Record | Essential information |
|---|---|
| Organization/site | Network, address, local time zone, opening/receiving windows, approved handling capabilities |
| Membership/contact | Authenticated account, organization, role, active status, assigned collections |
| Offer/food lot | Kitchen, description, declared quantity and unit, packaging, ingredients/allergens, holding information, availability, source, revision |
| Need | Receiving site, service window, desired/maximum quantity, unit, restrictions, current held/committed amounts, last confirmation, expiry, revision |
| Source event | Original input, verified sender/context, event time, arrival time, source ID, extraction/confirmation state |
| Proposal | Offer and need revisions, proposed requests/questions, evidence IDs, short explanation, model/run reference |
| Allocation | Food lot, receiving need, quantity/unit, state, hold expiry, collector, pickup window, revisions |
| Transport agreement | Named approved collector, assigned trip/window, capacity and handling confirmation, source of agreement |
| Custody/receipt event | Who handed over or accepted which quantity, unit, time, account, confirmation method, discrepancy |
| Command/event | Caller, request ID, input hash, outcome, case ID, recorded changes |
| Notification outbox | A saved delivery intention, stable ID, case revision, destination, attempts, next attempt, delivery state |
| Exception | Specific obstacle, affected quantity/commitment, responsible person, due time, resolution and source |

Several food lots may belong to one kitchen offer. Keep units explicit. The first automatic path uses meal boxes; a tray or kilogram is not silently converted into a meal count. Unsupported or uncertain conversions require coordinator input with a recorded source.

Need is shared across offers. If a shelter needs 50 boxes, commitments from all kitchens must consume that same need. Collector availability is also shared; one person cannot be automatically confirmed for overlapping trips.

Store time as an unambiguous instant plus the site's named time zone for display. Input needs a local date, not just “6 PM.” Test midnight, daylight-saving changes, and late-arriving messages. Collection availability and food-handling limits are separate fields; extending a kitchen's opening time does not extend food suitability.

## 4. Reserve stock and need together

The server applies a proposed invitation in one short database transaction:

1. Verify the authenticated caller and intended action.
2. Check the current offer, need, and proposal revisions and deadlines.
3. Conditionally increase the lot's held quantity only if enough is available.
4. Conditionally increase the need's held quantity only if receiving capacity remains.
5. Save the allocation, command outcome, event, and notification intention.
6. Commit everything together; otherwise roll it all back.

Check affected-row counts after conditional SQL updates. Update multiple records in a stable order, handle contention, and return a clear changed-capacity result. Never read a count and decrement later without protection. Never hold a database transaction while calling a model, waiting for a person, or sending email.

Example: two kitchens each propose 35 boxes to a shelter with capacity 50. After the first hold, the second 35-box request must fail its current-capacity check. The next plan can offer at most 15 there. An old agent proposal cannot override the new state.

Acceptance converts the same hold to a commitment; it does not subtract stock again. Partial acceptance releases only the difference. Hold expiry and acceptance must compete through the same state/revision check, so exactly one state transition wins locally.

Confirmed collections do not return to available stock merely because a timer passes. Someone may have collected without the record reaching the server. An overdue confirmed pickup creates follow-up work until custody is established.

[SQL updates and affected rows](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_update).

## 5. Real shortages are facts, not invalid database rows

An 80-box declaration and a later physical observation of 70 boxes are different events. Preserve both. Record the ten-box shortfall, stop unsupported new promises, and identify affected commitments.

The coordinator proposes an amendment or cancellation. Affected people explicitly agree to the changed quantity/time. A collector already travelling needs a specific update. Do not silently reduce a reservation, invent an extra donor, or rewrite the earlier record to make the totals look consistent.

Collected, accepted, returned, rejected, and reported-damaged quantities remain distinct. Rejected or returned food is not automatically available for another shelter. Its custody and permitted next step need a recorded resolution under the network's rules.

A receipt of 33 against a 35-box handoff remains 33 received. The other two belong to a specific unresolved outcome. Closing a coordinator note alone must not turn them into received food.

Manual phone confirmations require the named source, time, coordinator identity, and method. Keep them distinguishable from direct signed-in confirmation. Reports awaiting verification remain reports.

## 6. Retry safely, including after a lost reply

Every modifying command has an idempotency key: one identifier reused when retrying the same request. Save it with the caller, action, resource, input hash, and final outcome. A duplicate returns the saved outcome; the same key with changed input is rejected. Editing the intention creates a new key.

For slow work, return a pending response only after durable admission is established. The browser checks the command-status endpoint. A lost HTTP reply means “check the saved result,” not “repeat the business action with a new ID.” Verify the actual native queue/admission behavior before promising this property.

The outbox is a database table of notifications still to send. Save its row in the same transaction as the business change. A worker sends after commit and records the result. A restart must recover pending work.

Choose one retry owner. Do not combine an unbounded native-operation retry with another unbounded outbox retry. Use bounded attempts, backoff, and a coordinator task for unresolved outcomes. Before sending an old message, check that it has not been superseded or expired.

An email server acknowledging a message does not establish that the person read it. A lost email acknowledgement may produce a duplicate message; it must still link to the same invitation and cannot create another reservation. Do not claim exactly-once delivery to an outside system.

Use native service scheduling first. A custom adapter is justified only if it provides needed integration behavior; it is not added just to collect points.

## 7. Give the agent a bounded decision

The model handles informal language and incomplete information. For example, “our van should be back around six” should produce a confirmation question, not an invented collector agreement.

Proposed tools:

- `ReadOffer`: current food facts and original evidence for this case.
- `ReadCurrentNeeds`: authorized, current receiving needs and restrictions.
- `ReadCollectionFacts`: actual transport agreements and uncertainty.
- `ReadCaseEvidence`: bounded source records already authorized for this case.
- `SubmitProposal`: save a structured plan or clarification request for validation.

Tools receive their trusted case/user scope from the server. A model-supplied organization ID cannot grant access. Do not expose arbitrary SQL, file access, shell commands, recipient selection outside the network, or a tool that approves its own booking.

Proposal outcomes: **propose recipient requests**, **request missing information**, **require coordinator review**, or **no feasible plan**. Include quantities, current record revisions, source IDs, missing facts, and a short understandable reason. No generated reasoning transcript is needed.

Validate both the shape and meaning: permitted IDs, evidence belonging to this case, quantities, deadlines, current revisions, allowed transitions, and explicit confirmation requirements. Recheck scarce resources inside the commit transaction, even if proposal validation passed.

OpenAI strict function schemas constrain shape, not truth or authorization. Verify whether the chosen Hub build exposes the required strict/schema settings; do not assume every raw OpenAI parameter passes through the SDK. Application validation remains mandatory.

Initial diagnostic model: `gpt-4.1-mini`, available to the supplied key and documented for tool calling. This is a compatibility baseline, not a final quality or cost claim. Compare it with a stronger model on labeled cases before choosing the release model. Log the actual returned model/snapshot when available.

Proposed starting limits: four tool-call rounds, bounded output, a provider request timeout, and a total decision deadline. Exact settings must be tested on the accepted build. A timed-out workflow may leave an in-flight model call; late proposals must fail their deadline/revision checks. Manual planning remains possible with the same business rules.

[OpenAI function schemas](https://developers.openai.com/api/docs/guides/function-calling#strict-mode), [baseline model](https://developers.openai.com/api/docs/models/gpt-4.1-mini), [Hub limits and tools](https://github.com/intersystems-community/ai-hub-eap/blob/1cca39afeb069413846c4c31196eed0b731f793a/ObjectScript_SDK_Guide.md).

## 8. Human review and ordinary screens share the same truth

Use native Workflow Engine tasks for genuine coordinator work. Bind approval to the proposal and relevant record revisions. If stock or needs change during review, show what changed and require a current decision.

Production roles: kitchen contact, receiving contact, assigned collector, coordinator, and network administrator. The browser never chooses its own trusted role. Background workers carry the verified caller context and enforce organization/case permissions. SQL row-level security does not cover direct object reads automatically.

Use one role-aware browser app over the server interface. The final visual design is undecided. Build navigation for multiple offers, tasks, and collections rather than stretching the old single-case page. Keep uncertainty visible without making users operate queues or model settings.

Fast input can show “Sending acceptance.” Only a server-confirmed result can show “35 boxes reserved.” Connection loss preserves the draft and request ID. A pending offline action cannot become a global reservation. Saved pickup instructions show when they were last updated.

[Native Workflow Engine](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EGWF_dev), [row-security boundaries](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_rls).

## 9. Trace what actually happened

Correlate offer, allocation, command, source event, agent run, human task, and notification IDs. Record actor, before/after revision, observed model, tool calls, outcome, timing, and available token usage. Keep unknown usage or retries unknown. Never log keys or unnecessary personal information.

Native Visual Trace must show the business chain. The agent run should be a native request/response; tool evidence needs its own recorded detail. One `Chat()` can include several provider exchanges. An agent-run wrapper alone does not prove each individual model call is traced.

The Community Opportunity tracing bonus needs a reproducible implementation and correct idea links. Inspect actual provider hooks before claiming it. Embedded Python and vector-search bonuses likewise require real native execution/use, not merely Python files or a schema field.

## 10. Build and prove it in this order

1. **Runtime:** load the licensed AI Hub image; verify version and compiled Hub classes; make one native tool call through OpenAI. No browser SDK bypass.
2. **One integration case:** incoming offer, native agent proposal, actual email into a local test inbox, authenticated reply, saved reservation, handoff, receipt. Explain every simulated boundary.
3. **Real shared capacity:** several offers/kitchens competing for the same need; stock/need transactions and request recovery.
4. **Exceptions:** expiry versus acceptance, quantity shortage, changed food facts, overlapping collectors, stale approval, failed delivery, restart during pending work, and missing receipt.
5. **Final interface:** design around these states and real working data. Do not reskin the rejected sketch or invent activity while the backend is absent.
6. **Release:** clean installation, native tests and traces, package verification, walkthrough, useful bonuses, and honest limits.

Specific native checks must include two simultaneous reservations for the last stock, two kitchens consuming the same remaining need, acceptance racing expiry, duplicate callbacks, a reply lost after commit, and restart recovery. Browser tests cannot establish these properties.

Synthetic decision cases should include tentative language, stale need, incompatible units, changed ingredients, unknown handling, old messages arriving late, no collector, and malicious instructions embedded in source text. Measure false confirmations and missed questions, not just JSON validity.

## 11. Resources and current evidence

Core: an accepted AI Hub Community image and an OpenAI key with usable model access. No additional paid API is required for local implementation. A local mail inbox supports integration testing. Public hosting and a live email service are later deployment needs; maps, SMS, a driver marketplace, and external vector databases are not prerequisites.

Verified here: Docker is available; the supplied OpenAI key can list models; `gpt-4.1-mini` is among the accessible model IDs. This read-only check does not establish generation billing or a successful native provider call.

Installation is waiting on the licensed archive. The official portal reaches an InterSystems sign-in page; the accepted build-109 tag was absent from the public registry. No IRIS image, native classes, concurrent SQL behavior, or live Hub run has been tested here yet.

No source code from another contest entry is reused. Public Hub samples inform the native interfaces. The rejected preview contributes a flow sketch only; its local state and visual design do not become the backend or final UI.
