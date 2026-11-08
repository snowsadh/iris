# Project journey

Record project decisions, design tradeoffs, experiments, and lessons useful for articles, revision, or recovering project context. Dates use India time.

## 2026-11-09 — Understand contest before choosing idea

- **Work:** Read contest announcement, organizer replies, bonus rules, and linked platform guides. Saved research in [INFO.md](INFO.md).
- **Learned:** Entry needs an IRIS integration workflow where an AI Hub agent makes a decision. IRIS Agentic Dev is optional coding help.
- **Important corrections:** Submission and voting have different deadlines. Newer organizer replies accept build 109 despite older build-154 wording. Video bonus needs downloadable file; YouTube alone is insufficient.
- **Why it matters:** Reading replies revealed requirements that headline announcement did not fully reflect. Sources and exact versions stay in research notes.
- **Status:** No app idea, model, or architecture chosen. No IRIS image downloaded or workflow tested.

## 2026-11-09 — Explore candidates and set the execution standard

- **Candidate status:** No idea selected. Food rescue is one option worth exploring. User explicitly clarified that interest does not lock it in. Avoid shipment recovery overlap with RouteGuard and IRIS Chronos.
- **Quality reference:** After reviewing OcuPilot, user highlighted two strengths: a useful idea built for IRIS users and thorough documentation with clear resources. Our target includes both technical originality and execution.
- **Design question:** For each candidate, what useful technical contribution makes it stand out and fits this contest? OcuPilot's original contest specifically asked for a new IRIS management interface; its platform focus must be read in that context.
- **Next:** Keep comparing ideas and their technical contributions before selection. No app, architecture, or implementation chosen.

## 2026-11-09 — Treat professional delivery as part of the project

- **User standard:** OcuPilot feels like a serious open-source project because its implementation and documentation work together. Aim for that level of care across the finished submission.
- **Learning:** Judge guidance asks for useful technical originality, reliable setup, a working demonstration, and clear explanations. Repository evidence helps distinguish these from feature claims.
- **Decision:** Evaluate candidate ideas by the quality of the finished app we can deliver, as well as the problem they address. Documentation and repeatable checks belong throughout development.
- **Limit:** Professional presentation also appears in lower-ranked entries. It is our quality target, not a proven formula for winning. No idea selected.
- **Source:** [Expert guidance](https://community.intersystems.com/post/what-experts-look-contest-entries).

## 2026-11-09 — Separate idea discovery from delivery planning

- **Search brief:** Broaden the contest sites. Compare the main idea, approach, story, and room for distinctive technical work.
- **Learning:** An inspiring project need not already use IRIS or have our target documentation quality. We must judge the concept separately from the work needed to adapt and deliver it.
- **Method:** Keep original project descriptions separate from our proposed versions. Label award claims carefully. Ordered recommendations guide exploration; they do not select our project or predict prizes.
- **Status:** No idea selected. Candidate details and source links stay in private idea notes.

## 2026-11-09 — Check feasibility below the feature list

- **Work:** Mapped the four candidates under review to documented IRIS services, processes, operations, agent tools, storage, and review steps. Detailed comparisons stay in private idea notes.
- **Learning:** Database support alone does not prove an integration workflow. The agent needs a real decision, and ordinary code must enforce permissions and valid state changes.
- **Useful limits:** SQL row-level security does not cover direct object reads. A database transaction cannot guarantee that a separate web request happens exactly once. Waiting processes can be saved and resumed instead of holding a worker open.
- **Evidence boundary:** Read official guides and sample classes. No accepted AI Hub image is available, so native compilation and end-to-end checks remain pending.
- **Next:** Keep idea selection open. Verify a small native workflow on the accepted image before committing to its full architecture.

## 2026-11-09 — Separate a competitive plan from a valid submission

- **Check:** Rechecked current entries, organizer corrections, judging advice, and all published bonuses. The contest page showed 36 entries. Candidate-specific comparisons remain private.
- **Time constraint:** At 03:24 IST, about seven hours remained before initial registration closed. No app or accepted runtime had been validated. Improvements during voting do not remove the need for a working initial entry.
- **Learning:** Track fit, distinctive value, and an achievable release are separate questions. A familiar evidence-review pattern needs a specific contribution to stand out; adding bonus features alone does not provide it.
- **Next:** Use [SUBMISSION.md](SUBMISSION.md) to prioritize a complete native case and reliable setup before optional additions. No idea selected and no release outcome claimed.

## 2026-11-09 — Select food rescue and begin with real handoffs

- **Decision:** User selected food rescue. Other candidates remain private references.
- **Product standard:** Start with a person's actual situation and follow the work through input, decisions, commitments, physical action, confirmation, and recovery. The interface must make sense without hearing the pitch.
- **Important distinction:** A suggested recipient is not a reservation. A reservation is not collection. Collection is not confirmed receipt. Each step needs a responsible person and visible evidence.
- **Initial design assumption, then confirmed:** User chose known kitchens and shelters with a coordinator. Partner interviews and local operating rules remain unverified.
- **Next:** Define the complete case, screen actions, and failure handling before building the native workflow. Product behavior is planned; no live app is claimed.

## 2026-11-09 — Make the food journey visible and reviewable

- **Designed:** Followed a kitchen's meal-box offer through coordinator review, explicit recipient commitments, named collection, physical handoff, and receiving confirmation. Saved the complete story in [PRODUCT.md](PRODUCT.md) and screen behavior in [INTERFACE.md](INTERFACE.md).
- **Practical lessons:** Usual shelter capacity is not today's need. Tentative transport is not a confirmed collector. A receipt count is not a claim that people were fed. Handling rules still need a real network and location.
- **Built for review:** A local interface sketch with fictional partners, a full case, and selected failure paths, introduced in commit `23aa834`. It used no live messaging, authentication, model, or native IRIS runtime. The rejected sketch was later removed from active code.
- **Review finding:** An outdated transport warning stayed visible after acceptance. Changed the next-action panel to follow current state and responsibility. Also made receipt shortfalls and withdrawn quantities remain visible rather than disappearing into a success state.
- **Verification:** Browser checks passed for the complete local case and selected failure paths, including a mobile receipt. Desktop/mobile screenshots were inspected. These checks applied to the discarded sketch, not the native app.
- **Next:** Review this product flow, then implement and verify the native integration, actual partner communication, and operational rules. A clickable example is not a submitted service or field validation.

## 2026-11-09 — Reject the visual shortcut and design for shared work

- **User feedback:** Agreement with the flow did not approve the interface. The sketch looked generic and its single-case world was too small. Use realistic international placeholder profiles.
- **Repository decision:** Removed the rejected sketch and its browser checks from active code. Git history preserves the experiment; current docs retain its useful lessons without carrying its simulated state into the application.
- **Technical correction:** Capacity belongs to the whole network day, not each screen. Food stock, receiving need, and collection availability must be checked together. Quantity shortfalls and unknown custody remain explicit rather than being rewritten into a success state.
- **Implementation preparation:** Added licensed-image setup and native class verification. Archive/platform and private-configuration preservation checks pass; those checks are not evidence of a working native workflow. A local test email inbox is available for the first integration case.
- **Working standard:** Review coherent responsibilities, actual failures, and screenshots at meaningful milestones. Keep the repository small and remove work that no longer serves the product.

## Entry pattern

Project name chosen on 9 November 2026: **Allfedo**.

Use only fields that help:

- **Date and event:** What changed?
- **Decision or problem:** What did we choose or encounter?
- **Reason:** Why?
- **Evidence and lesson:** What did we observe or verify?
- **Next:** What follows?
- **Links:** Relevant code, sources, issue, or commit.
