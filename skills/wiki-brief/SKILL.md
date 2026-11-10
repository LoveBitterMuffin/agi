---
name: wiki-brief
description: Assemble precise context package (rules, wiki summary, raw ranges, code outlines) for a given task.
---
1. Ensure `memory/` exists (run `.agents/scripts/get-memory-brief.ps1 -Init` if missing) to satisfy the Carpati Memory Gate, then run `.agents/scripts/get-memory-brief.ps1 -Query "<task-keywords>"` or range-read `memory/logs/ActiveSprintLog.md` and `memory/Index.md`.
2. Inspect `memory/MOC.md` and `memory/Index.md` to map target chapters (`CH-NNN`) and cross-module dependencies.
3. Range-read relevant `memory/wiki/chapters/*.md` and `099_learnings.md` (`<=250` lines per read), plus `memory/raw/vault/RAW-YYYY-NNN_<slug>.md lines X-Y` when deeper ground truth is required.
4. Extract code signatures via symbol outlines (`view_file_outline`) across auto-detected project source roots (`src/`, `handwriting_system/src/`, `app/`, `lib/`, `packages/*/src/`) — never full-read files `>250` lines.
5. Return a clamped 4-block context package (`<=35` lines): Active Sprint & Constraints, Target Chapter Rules & Code Entrypoints, Cross-Module Contracts, and Learnings/Versions for Gate 0 and subagent `Resource Boundaries`.
