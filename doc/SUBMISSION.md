# Contest 49: submission checklist

Checked 9 November 2026. No app has been built or tested yet. Boxes below are work to complete, not claims of progress.

## Required

- [ ] Confirm participant eligibility and create Community / Open Exchange accounts. Add team profile links if entering as a team.
- [ ] Load an accepted AI Hub Community Docker image. Build 2027.1.0AI.109.0 is accepted; declare the exact build. Document image loading and `docker compose up`. Do not publish the proprietary image.
- [ ] Build an original, functional IRIS Interoperability workflow. Its AI Hub agent must make a real decision that changes the workflow's next step.
- [ ] Publish source on GitHub or GitLab under an open-source license. Credit reused work.
- [ ] Write an English README with installation steps and either a video or a clear description of how the app works. Include dependencies, sample input, provider-key setup, and expected output.
- [ ] Create the Open Exchange listing, add repository and license links, and send it for approval. A saved draft is not a submitted listing.
- [ ] Apply the app to contest 49 and verify the association before **9 November, 10:29:59 AM IST**. A pending review is allowed; the app still needs to work.

Improvements are allowed during voting, which ends 16 November at about 10:29 AM IST. This does not extend initial registration or permit a nonfunctional placeholder.

[Contest rules](https://openexchange.intersystems.com/contest/49), [organizer corrections and deadlines](https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows), [listing guide](https://docs.openexchange.intersystems.com/apps/submit/).

## Quality work: our standard, not extra entry rules

- [ ] Finish one understandable case from intake through agent decision to confirmed result. Label simulated connections and synthetic data.
- [ ] Make the main screen show the evidence, next action, review state, and result clearly.
- [ ] Check normal operation, repeated input, stale information, rejected proposals, and unavailable model/provider. Add case-specific checks where failure would break the main promise.
- [ ] Repeat installation from clean source. Keep build, model, configuration, and sample data reproducible.
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
