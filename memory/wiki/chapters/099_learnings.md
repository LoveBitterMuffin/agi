---
chapter_id: CH-099
version: 1.0.0
status: active
updated: 2026-11-10
---
# 099: System Learnings & Known Pitfalls

## Architectural Invariants
1. Do not accumulate tool calls in main thread; delegate tasks modifying >=2 files to subagents.
2. Always execute Gate 0 ask_question before drafting specifications or coding.

## 4. Template for Logging New Learnings
```markdown
### [LRN-YYYY-NNN] <Short Descriptive Title>
- **Date / Trigger:** YYYY-MM-DD / <Command, Test, or Spec Context>
- **Root Cause:** <Technical mechanism of the failure with file/line refs>
- **Anti-Pattern:** <What failed and must be avoided>
- **Deterministic Invariant:** <Concrete, verifiable rule preventing recurrence>
- **Verification Evidence:** <Shielded test command and pass proof>
```