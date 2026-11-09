# Contest 49: submission checklist

Checked 9 November 2026. The working app, redirection and linked physical outcomes passed a fresh installation at `f6459b6`: new application data, no provider key, all native groups, demo accounts and the five-account browser journey. See [validation](VALIDATION.md). Final source review is underway. No Open Exchange submission has been made.

## Required

- [ ] Confirm participant eligibility and create Community / Open Exchange accounts. Add team profile links if entering as a team.
- [x] Load an accepted AI Hub Community Docker image. Actual build `2027.1.0AI.109.0` is running; [README](../README.md) covers loading, startup and native checks. The proprietary image stays local.
- [x] Build an original, functional IRIS Interoperability workflow. A real native AI Hub proposal created no hold until the coordinator sent it separately. Signed-in browser journeys also completed physical handoffs and explicit recovery.
- [x] Publish source on GitHub or GitLab under an open-source license. [Working source](https://github.com/snowsadh/iris/tree/feature/allfedo-core) uses MIT; final default-branch merge remains release work. Third-party font and vendor terms stay separate.
- [x] Write an English README with installation steps and a clear description of how the app works. Dependencies, sample case, provider-key setup, expected outcomes and actual screenshots are included. A video is optional for entry.
- [ ] Create the Open Exchange listing, add repository and license links, and send it for approval. A saved draft is not a submitted listing.
- [ ] Apply the app to contest 49 and verify the association before **9 November, 10:29:59 AM IST**. A pending review is allowed; the app still needs to work.

Improvements are allowed during voting, which ends 16 November at about 10:29 AM IST. This does not extend initial registration or permit a nonfunctional placeholder.

[Contest rules](https://openexchange.intersystems.com/contest/49), [organizer corrections and deadlines](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows), [listing guide](https://docs.openexchange.intersystems.com/apps/submit/).

## Quality work: our standard, not extra entry rules

- [x] Complete the workflow. A real native agent proposal and separate send passed; independent signed-in browser journeys verified physical handoffs, receipt and recovery. Automated browser plans are explicitly manual, and physical actions are simulated.
- [x] Show evidence, next action, review state and result. Desktop and phone screenshots were inspected; human usability checks remain for the participant.
- [x] Check normal operation, repeated input, stale information, rejected proposals, unavailable provider, temporary locks, email and physical outcomes.
- [x] Repeat installation from clean source at `f6459b6`, using only the already-loaded licensed image. Fresh data, setup, all 17 native groups, six demo accounts, time checks and the complete browser journey passed. No provider key or development data was reused.
- [x] Provide the [walkthrough](WALKTHROUGH.md), [implementation guide](TECHNICAL_PLAN.md), [partner interface](API.md) and [validation record](VALIDATION.md).
- [x] Record actual model/tool calls, timing, available token usage and outcomes. Unknown usage remains unknown; no recorded replay is presented as a live call.

[Expert guidance](https://community.intersystems.com/post/what-experts-look-contest-entries) recommends technical originality, reliable setup, a complete workflow, and relevant bonuses. It is not a weighted scoring formula.

## Optional bonuses

Every row is a bonus, not an additional mandatory feature. Claim it only with working evidence.

| Bonus | Points | What must exist |
|---|---:|---|
| Docker | 2 | IRIS running in a container. |
| Workflow Engine | 2 | Native engine assigns human tasks. |
| Embedded Python | 3 | Useful Python code runs inside IRIS. |
| IRIS Vector Search | 2 | App actually uses similarity search. |
| Published IPM package | 2 | Public package installs successfully. A manifest alone is insufficient. |
| Online demo | 2 | Working hosted workflow; static replay alone does not qualify. |
| First Community article | 2 | Explain the app and its use. |
| Second article or translation | 1 | Additional article about the app. |
| Demo video | 3 | Demonstrate product; provide a file downloadable without signing in. |
| Feedback questionnaire | 1 | Submit requested feedback. |
| Custom adapter | 2 | Develop an inbound/outbound adapter and use it in the Production. |
| Java/.NET Production Extension | 3 | Use that extension in the Production. |
| Community Opportunity idea | Up to 4 | Implement a qualifying idea; link it in README and listing. |
| Reproducible AI Hub bugs | 2 + 1 | First and second qualifying reports; maximum 3. |
| Reproducible Embedded Python bugs | 2 + 1 | First and second qualifying reports; maximum 3. |

[Official bonus list and conditions](https://community.intersystems.com/post/technology-bonuses-intersystems-programming-contest-ai-agents-interoperability-workflows).

Practical order: finish the required workflow, then setup and walkthrough. Add the video, article, feedback, and useful native review. Add further technology only when it strengthens the app. Bug reports depend on real findings; they are not planned feature work. Bonus awards remain the organizers' decision.

**Implemented evidence:** Docker runs the actual IRIS image; Embedded Python performs invitation checks and physical-stock reconciliation inside IRIS. The other bonuses are not claimed as completed. Video and other improvements can be added during voting; add the downloadable video link before voting closes rather than treating registration as the video deadline.

## Listing draft

Prepared text, not a submitted application. Review after the final source merge. Do not add an unrecorded video, unpublished article, local-only demo URL or unverified bonus claim.

| Field | Value |
|---|---|
| Application name | Allfedo |
| Repository | https://github.com/snowsadh/iris |
| Short description | Agree food pickups, handle changed plans, and confirm what actually arrived. |
| Technology | InterSystems IRIS; native AI Hub; Embedded Python. |
| Suggested tags | AI Hub, Interoperability, food rescue, Embedded Python. |
| Source license | MIT. Use the final default branch's LICENSE link after merging. |
| Documentation | Link to README and doc/WALKTHROUGH.md on the final default branch. |
| Support | https://github.com/snowsadh/iris/issues |
| Call to action | View source |
| Author | [Participant's Open Exchange profile](https://openexchange.intersystems.com/user/snow%2520sadh/AEXFstiBwfewHtVmKbTfiU73Vc), supplied by the participant. Eligibility remains theirs to confirm. |
| Logo | [1024-pixel PNG](assets/logo.png), exported from the app's own vector mark. |

Full description:

> Allfedo helps a local food-rescue team turn surplus food into agreed pickups and recorded receipts. Kitchens confirm what they have. Receiving partners confirm today's need, food requirements and receiving window. A coordinator reviews invitations, and an approved collector agrees the actual load and trip.
>
> An AI Hub agent runs inside an InterSystems IRIS Interoperability Production. It reads authorized food and receiving facts, then proposes a split or asks a concrete question. The coordinator sends separately. Current shared quantities, evidence, deadlines, allergens and handling are checked before food is held.
>
> The app keeps promises separate from physical facts. A smaller receiving count does not automatically put food back in kitchen stock or create replacement demand. Partners can report late events, correct an earlier count and agree a changed promise while preserving its history.
>
> If a destination is unavailable after collection, the collector reports the food still carried. A new receiving team accepts and the collector agrees the onward trip. Linked records preserve the original pickup and account for the whole load. Rejected food can later be returned or disposed of without counting the same boxes twice.
>
> Docker setup includes the signed-in app, private fictional partner accounts and a local test inbox. Native, HTTP and browser checks exercise the real runtime. The entry targets AI Hub Community build 2027.1.0AI.109.0 with OpenAI; checked manual planning remains available without a provider key.
>
> Demo data is fictional. This is not a field-validated food service or an automatic food-safety decision system.

Use available catalog options: Integration, AI Agents and Solutions are relevant categories; Supply Chain and Logistics is a relevant industry. Do not add a local-only URL as an online demo.

## Participant's final submission steps

1. Confirm eligibility and the author profile. A team needs all members' Community profile links; the organizer allows two to five members.
2. Sign in to Open Exchange. In the developer portal, create an application and import the repository. Review its name, logo, license, description and source links.
3. Preview it, then use **Send for Approval**. Saving a draft alone is insufficient.
4. Associate Allfedo with contest49 through the contest application control, and verify the association before the deadline. Preserve its status/URL for our checklist.
5. Add the recorded video's watch and signed-out download links when ready. Add only bonuses with working evidence.

The [general contest guide](https://docs.openexchange.intersystems.com/contest/apply/) describes published apps. The [contest-specific organizer reply](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows) expressly allows approval to remain pending at the deadline. Verify the actual contest association; do not assume sending for approval automatically enters it. [Listing form guide](https://docs.openexchange.intersystems.com/apps/submit/).
