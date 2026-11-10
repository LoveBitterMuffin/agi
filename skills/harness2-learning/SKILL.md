---
name: harness2-learning
description: Google Research Harness² Propose-Probe-Compose methodology for recursive error-driven learning and scaffolding evolution into 099_learnings.md.
when_to_use: "Activated immediately upon test failure, compiler error, runtime exception, or reviewer rejection during subagent execution."
allowed-tools: Read, Write, Edit, Grep
version: 1.0.0
priority: CRITICAL
---

# Harness² Error-Driven Self-Learning Protocol

> **Google Research Harness² Methodology:** Recursive scaffolding and prompt evolution through empirical failure distillation.

The Harness² protocol transforms runtime errors and test regressions into permanent system immunity. Instead of treating failures as ephemeral obstacles, Harness² systematically executes the **Propose-Probe-Compose** loop, distilling verified fixes into `memory/wiki/chapters/099_learnings.md` and active memory rules.

---

## 1. The Propose-Probe-Compose Cycle

```
[Runtime Error / Test Regression]
                │
                ▼
      ┌──────────────────┐
      │  Phase 1: PROPOSE │ ──► Formulate root-cause hypothesis & prompt/scaffold diff
      └─────────┬────────┘
                │
                ▼
      ┌──────────────────┐
      │  Phase 2: PROBE   │ ──► Execute isolated test probe (Workspace: "branch")
      └─────────┬────────┘
                │
         [PASS / FAIL]
         ├── FAIL ──► Refine hypothesis (max 2 retries)
         │
         └── PASS
                │
                ▼
      ┌──────────────────┐
      │ Phase 3: COMPOSE  │ ──► Extract lesson to 099_learnings.md & update active memory
      └──────────────────┘
```

### Operational Phases

| Phase | Action | Criteria & Deliverable |
|:---|:---|:---|
| **1. Propose** | Analyze failing stack trace, error logs, and environment state. Formulate an explicit, minimal hypothesis for correcting the prompt, resource boundaries, or code invariant. | A concrete hypothesis stating: Root cause, failing invariant, proposed correction. |
| **2. Probe** | Run an isolated test probe in a branched workspace (`Workspace: "branch"`) using shielded execution (`run-shielded.ps1`). Never mutate production trunk before probe succeeds. | Exit code 0, execution duration, and isolated test pass verification. |
| **3. Compose** | Upon successful probe, commit the code change and permanently record the incident in `memory/wiki/chapters/099_learnings.md`. Propagate the distilled rule to the active working context. | Entry added to `099_learnings.md` following the mandatory schema below. |

---

## 2. Mandatory `099_learnings.md` Entry Schema

Every composed finding MUST be appended to `memory/wiki/chapters/099_learnings.md` using this compact format:

```markdown
### [LRN-YYYY-NNN] <Descriptive Title>
- **Date / Trigger:** YYYY-MM-DD / <Failing command or test ID>
- **Root Cause:** <Precise technical explanation of the failure mechanism>
- **Anti-Pattern:** <What naive approach failed>
- **Deterministic Invariant:** <Exact rule, regex, or type constraint that prevents recurrence>
- **Verification Evidence:** <Shielded test command and pass proof>
```

---

## 3. Autonomous Self-Healing Integration (`--SelfHeal`)

When the 4-stage harness detects:
1. **SemVer Drift:** Mismatch between git diff changes and chapter versions.
2. **Broken Memory Links:** Invalid `memory/raw/` line pointers or unresolvable wiki links.
3. **Micro-Modularity Violations:** Files exceeding 150 lines or empty `catch` blocks.

The agent activates `--SelfHeal`:
- Automatically recalculates SemVer based on commit diff.
- Runs auto-formatting and pointer repair via `.agents/scripts/self-heal.ps1`.
- If self-healing succeeds within 2 retries, execution continues. If unresolvable, escalates to the user via Gate 1.X.
