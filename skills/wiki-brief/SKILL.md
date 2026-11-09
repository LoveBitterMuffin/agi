---
name: wiki-brief
description: Assemble precise context package (rules, wiki summary, raw ranges, code outlines) for a given task.
---
1. Execute `.agents/scripts/get-memory-brief.ps1 -Query "<task-keywords>"` (or read `memory/Index.md` and `memory/logs/ActiveSprintLog.md`).
2. Identify target chapters and dependency graph.
3. Read respective `memory/wiki/chapters/`. Fetch raw lines via range reads if needed.
4. Extract code signatures via AST outlines on `src/`.
5. Return a strict 4-block context package: Constraints, Code Entrypoints, Cross-Module Contracts, Versions.
