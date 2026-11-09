# Contest 49: submission checklist

Checked 9 November 2026. The signed-in app and recovery journey run on the actual contest image. A clean clone with fresh volumes passed setup, native checks, demo accounts and browser checks at `e0bc9b9`. Destination redirection and final release review remain underway. No Open Exchange submission has been made.

## Required

- [ ] Confirm participant eligibility and create Community / Open Exchange accounts. Add team profile links if entering as a team.
- [x] Load an accepted AI Hub Community Docker image. Actual build `2027.1.0AI.109.0` is running; [README](../README.md) covers loading, startup and native checks. The proprietary image stays local.
- [x] Build an original, functional IRIS Interoperability workflow. A real native AI Hub proposal created no hold until the coordinator sent it separately. Signed-in browser journeys also completed physical handoffs and explicit recovery.
- [x] Publish source on GitHub or GitLab under an open-source license. [Working source](https://github.com/snowsadh/iris/tree/feature/allfedo-core) uses MIT; final default-branch merge remains release work. Third-party font and vendor terms stay separate.
- [ ] Write an English README with installation steps and either a video or a clear description of how the app works. Include dependencies, sample input, provider-key setup, and expected output.
- [ ] Create the Open Exchange listing, add repository and license links, and send it for approval. A saved draft is not a submitted listing.
- [ ] Apply the app to contest 49 and verify the association before **9 November, 10:29:59 AM IST**. A pending review is allowed; the app still needs to work.

Improvements are allowed during voting, which ends 16 November at about 10:29 AM IST. This does not extend initial registration or permit a nonfunctional placeholder.

[Contest rules](https://openexchange.intersystems.com/contest/49), [organizer corrections and deadlines](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows), [listing guide](https://docs.openexchange.intersystems.com/apps/submit/).

## Quality work: our standard, not extra entry rules

- [ ] Finish one understandable case from intake through agent decision to confirmed result. Label simulated connections and synthetic data.
- [ ] Make the main screen show the evidence, next action, review state, and result clearly.
- [ ] Check normal operation, repeated input, stale information, rejected proposals, and unavailable model/provider. Add case-specific checks where failure would break the main promise.
- [x] Repeat installation from clean source. At `e0bc9b9`, cloned the public branch, reused only the already-loaded licensed image, created fresh isolated volumes, and passed setup, all native groups, demo account verification, time checks and the full browser journey. No provider key or development data was reused. Repeat after the remaining core changes.
- [ ] Give reviewers a short walkthrough. Explain architecture, useful technical choices, limits, and troubleshooting.
- [ ] Record actual model/tool calls, timing, available token usage, and outcomes. Label live calls and recorded replays separately.

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
| Author | Participant's confirmed Open Exchange profile; still needed. |

Full description:

> Allfedo helps a local food-rescue team turn surplus food into agreed pickups and recorded receipts. Kitchens confirm what they have. Receiving partners confirm today's need, food requirements and receiving window. A coordinator reviews invitations, and an approved collector agrees the actual load and trip.
>
> An AI Hub agent runs inside an InterSystems IRIS Interoperability Production. It reads authorized food and receiving facts, then proposes a split or asks a concrete question. The coordinator sends separately. Current shared quantities, evidence, deadlines, allergens and handling are checked before food is held.
>
> The app keeps promises separate from physical facts. A smaller receiving count does not automatically put food back in kitchen stock or create replacement demand. Partners can report late events, correct an earlier count and agree a changed promise while preserving its history.
>
> Docker setup includes the signed-in app, private fictional partner accounts and a local test inbox. Native, HTTP and browser checks exercise the real runtime. The entry targets AI Hub Community build 2027.1.0AI.109.0 with OpenAI; checked manual planning remains available without a provider key.
>
> Demo data is fictional. This is not a field-validated food service or an automatic food-safety decision system.

Update that text after redirection passes its complete browser journey. Use the closest available application category and social-impact industry; do not invent catalog options.

## Participant's final submission steps

1. Confirm eligibility and the author profile. A team needs all members' Community profile links; the organizer allows two to five members.
2. Sign in to Open Exchange. In the developer portal, create an application and import the repository. Review its name, logo, license, description and source links.
3. Preview it, then use **Send for Approval**. Saving a draft alone is insufficient.
4. Associate Allfedo with contest49 through the contest application control, and verify the association before the deadline. Preserve its status/URL for our checklist.
5. Add the recorded video's watch and signed-out download links when ready. Add only bonuses with working evidence.

The [general contest guide](https://docs.openexchange.intersystems.com/contest/apply/) describes published apps. The [contest-specific organizer reply](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows) expressly allows approval to remain pending at the deadline. Verify the actual contest association; do not assume sending for approval automatically enters it. [Listing form guide](https://docs.openexchange.intersystems.com/apps/submit/).
