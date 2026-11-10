---
name: release-audit
description: Verify git diff against wiki docs, bump SemVer versions, update CHANGELOG, and compact logs.
---
1. Run `git diff` across auto-detected project source roots (`src/`, `handwriting_system/src/`, `app/`, `lib/`, `packages/*/src/`) and `.agents/` (or execute `.agents/scripts/release-audit.ps1`).
2. Synchronize `memory/wiki/chapters/*.md` rules and lossless vault pointers (`RAW-YYYY-NNN_<slug>.md lines X-Y`) with actual code changes.
3. Calculate SemVer bump (`MAJOR`/`MINOR`/`PATCH`), set chapter `status: active`, and update `memory/Index.md` and `memory/MOC.md`.
4. Append the release record to `memory/logs/CHANGELOG.md`, record any failure invariants in `099_learnings.md` (`.agents/scripts/record-learning.ps1`), and compact `memory/logs/ActiveSprintLog.md` if `>180` lines (`<=35` lines L0 brief).
5. Run `.agents/scripts/audit-memory.ps1` and verify Gate 3 Acceptance Criteria Evidence (`AC-*` `PASSED`/`FAILED`) before concluding.
