# Project journey

Record meaningful decisions, problems, and lessons. Keep entries short and useful for future articles or videos. Dates use India time.

## 2026-11-09 — Understand contest before choosing idea

- **Work:** Read contest announcement, organizer replies, bonus rules, and linked platform guides. Saved research in [INFO.md](../doc/INFO.md).
- **Learned:** Entry needs an IRIS integration workflow where an AI Hub agent makes a decision. IRIS Agentic Dev is optional coding help.
- **Important corrections:** Submission and voting have different deadlines. Newer organizer replies accept build 109 despite older build-154 wording. Video bonus needs downloadable file; YouTube alone is insufficient.
- **Why it matters:** Reading replies revealed requirements that headline announcement did not fully reflect. Sources and exact versions stay in research notes.
- **Status:** No app idea, model, or architecture chosen. No IRIS image downloaded or workflow tested.

## 2026-11-09 — Set working habits

- **Decision:** Keep lasting instructions in [AGENT.md](../AGENT.md). Standard [AGENTS.md](../AGENTS.md) points agents there.
- **Decision:** Commit meaningful progress in small, focused steps. Use clear messages. Use branches, issues, and pull requests when useful, explaining their purpose as we learn.
- **Decision:** Keep this journal for decisions and lessons. Root `IDEA.md` stays out of Git and awaits user's next instructions.
- **Blocker:** Session exposes `.git` as read-only. Git cannot recognize repository through that view, and initialization failed. No commit or remote repository link recorded yet.
- **Next:** Restore Git access, check existing repository before initializing anything, commit research and working-habit files, then capture user's idea instructions.

## 2026-11-09 — Explain blocked commits

- **Verified:** `.git` is a separate read-only mount inside command sandbox. Codex's workspace-write mode protects Git metadata. Current session also disables sandbox approval requests.
- **Correction:** Earlier claim that repository was uninitialized was too strong. Restricted view may hide existing Git metadata; check from normal terminal after access changes.
- **Lesson:** User authorization to commit and session's technical permission to write Git history are separate.
- **Next:** Enable approval requests in session settings, then retry Git inspection and commits. [Official permission guide](https://learn.chatgpt.com/docs/agent-approvals-security#protected-paths-in-writable-roots).

## 2026-11-09 — Restore Git access and start history

- **Changed:** User reopened session with unrestricted filesystem access. Git initialization now succeeds.
- **Verified:** No `.git` existed after sandbox restriction was removed. Initialized local repository on `main`, using existing Git author settings.
- **Saved:** Contest research in commit `a80b2ca` (`docs: record contest rules and development tools`). Working instructions and journal form next focused commit.
- **Checked:** `IDEA.md` matches root ignore rule and stays outside tracked files.
- **Next:** Continue with user's idea instructions. Remote repository is not configured yet; connecting one will enable hosted issues and pull requests.

## Entry pattern

Use only fields that help:

- **Date and event:** What changed?
- **Decision or problem:** What did we choose or encounter?
- **Reason:** Why?
- **Evidence and lesson:** What did we observe or verify?
- **Next:** What follows?
- **Links:** Relevant code, sources, issue, or commit.
