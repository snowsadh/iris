# Project instructions

## Keep this file current

- Follow these instructions throughout this project.
- Add lasting user instructions when given. Update old instructions when user changes them.
- Add useful project habits when evidence supports them. Label agent-added habits separately.
- Keep instructions short. Put research in `doc/INFO.md` and project history in `doc/JOURNEY.md`.

## User instructions

### Communication and research

- Use simple English and short, readable sentences. Keep caveman style without losing clarity.
- Explain unfamiliar terms before using them. Teach through concrete examples.
- Explain where tools, models, and decisions came from; what was reused; and what changed.
- Read contest requirements and relevant tool documentation carefully. Keep verified findings and source links in `doc/INFO.md`.
- Separate documented behavior, actual test results, examples, and unverified assumptions.
- When studying contest winners, compare implementation, validation, usability, presentation, and bonus points as well as idea. Include Expert and Freshmen awards; separate evidence from guesses about judges' preferences.
- Use OcuPilot as a quality reference for both useful technical originality and strong execution. Aim for complete behavior, clear resources, and documentation backed by working evidence.
- Treat professional implementation and documentation as core project work, not final polish. Evaluate the whole release: purpose, coherent behavior, setup, interface, tests, developer guidance, and honest limits.

### Git and collaboration

- Commit when a sensible piece of work is complete. Do not wait for huge batches or commit every tiny edit.
- Use short or medium commit messages in clear English. State concrete change and purpose.
- Format commits with a short title; add a brief body only when useful.
- After committing, show user commit hash and exact commit message, including body if present.
- Example title: `docs: record project workflow and learning journal`.
- Use branches, issues, and pull requests when they help organize real work or teach repository collaboration.
- Explain briefly why a branch, issue, or pull request exists. Do not create busywork.
- Never claim a commit, push, issue, or pull request succeeded without checking its result.

### Project journal

- Update `doc/JOURNEY.md` for project decisions, design tradeoffs, experiments, useful findings, and milestones.
- Include problems only when they teach something about our app, InterSystems, or contest requirements.
- Exclude assistant access, sandbox permissions, Git setup, and routine workflow housekeeping. Keep working instructions here.
- Record date, what happened, why it matters, and next step. Add source or commit links when available.
- Keep history truthful. Do not invent experiments, outcomes, or user decisions.
- Preserve enough context for future articles and videos. Skip routine edit-by-edit narration.
- Before adding entry, ask whether it helps write about project, revisit learning, or recover project context. Otherwise skip it.

### Idea notes

- Keep `doc/IDEA.md` ignored by Git. Preserve the root ignore rule for older local copies.
- Use it for contest and idea research as requested. Record sources, uncertainties, and candidate ideas; do not treat candidates as user's chosen project.
- No idea is selected yet. Interest in a candidate is not a decision; wait for explicit selection before calling it our project or working direction.
- Do not copy its contents into tracked files or public issues/PRs without user's instruction.

### Meko restrictions

- Use Meko only with explicit user or approved-project authorization and exact authorized `datapack_id` on every call.
- Never access `meko_default_datapack` or assume a missing datapack argument.
- No automatic memory searches, capture, writes, queue replay, repair, or reinstallation.

## Agent-added working habits

- Prefer smallest useful implementation. Add dependencies and complexity only for a clear need.
- Before committing, inspect changes, check for secrets and ignored files, and run checks appropriate to change.
- Keep each commit focused enough to explain and review.
- Build documentation alongside working features. Link important claims to code, demonstrations, or recorded checks; distinguish planned behavior from tested behavior.
- Reassess winner claims against the contest theme, dated source revisions, and comparable lower-ranked entries. Feature lists, badges, test counts, and repository size alone do not establish quality or judge preference.
- Recheck changing contest rules before relying on them. Preserve dated organizer corrections.
- If access blocks work, finish independent tasks and report exact blocker. Do not work around protected paths.
