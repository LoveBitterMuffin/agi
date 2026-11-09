---
trigger: always_on
description: Dual-Loop Decision Pipeline, Spec-First protocol, Human Alignment Gates, and Embedded CI/CD.
---

# 02: Dual-Loop Decision Pipeline & Spec-First Protocol

## 1. Core Architecture: The Dual-Loop Decision Model
The agent decision brain operates on a synchronized two-loop architecture:
1. **Loop 1: External Strategic Loop (Human Alignment):** Micro-feedback gates minimizing human prompt fatigue through 1-click structured decisions.
2. **Loop 2: Internal Execution Loop (Embedded CI/CD):** Autonomous swarm execution bound to continuous machine verification and self-healing.

---

## 2. The Four Human Alignment Gates

### Gate 0: Interactive Inquiry Pre-Selection (Deterministic Alignment)
- **Mandate (Absolute Gate Before Spec or Code):** For ANY new feature, redesign, architectural shift, or multi-step engineering task, the agent MUST NEVER jump straight into writing specifications, reading dozens of files, or writing code. The agent MUST FIRST call `ask_question` with 2–4 structured architectural, UX, or implementation options.
- **Pre-Calculated Default:** The technically optimal option MUST be placed first and prefixed with `(Recommended)`. The user can confirm the ideal path in a single click without prompt fatigue.
- **Strict Prohibition on Assumptions:** The agent is strictly prohibited from assuming user preferences on architecture, libraries, visual styles, or feature scope without passing through Gate 0.
- **Exemptions:** Only pure informational questions (e.g. "what is X?") or single-line typo/bug fixes are exempt.

### Gate 1: Formal Specification Sign-Off & Dynamic Inquiry Loop (Absolute Code Gate)
- **No Spec = No Code:** Implementation code in `src/**` MUST NEVER be written before an approved Specification exists.
- **Dynamic Gate 1.X (Sub-Gate Branching Inquiry):**
  When reasoning or drafting a specification, whenever architectural choices, UX variations, performance trade-offs, or scope customizations arise, the agent is **strictly prohibited from making assumptions**. The agent MUST immediately invoke `ask_question` (Sub-Gate 1.1, Sub-Gate 1.2, etc.) to resolve the branch interactively:
  1. *Architectural Branching:* Selection of data store, state management, communication protocols, or contract boundaries.
  2. *UX & Visual Variations:* Interaction paradigms, modal vs drawer layouts, responsive breakpoints, or density models.
  3. *Performance vs Complexity:* In-memory vs persistent caching, lazy vs eager loading, batching vs streaming pipelines.
  4. *Integration & Customization:* Third-party library adoption, platform hooks, or deployment targets.
- **Pre-Calculated Default:** Every sub-gate query MUST formulate 2–4 clear, structured options with the technically optimal choice placed first and prefixed with `(Recommended)` to enable frictionless 1-click resolution.
- **AC Matrix:** Formulate discrete Acceptance Criteria (`AC-01`, `AC-02`, etc.) covering functional behaviors, failure modes, and architectural invariants.
- **Hard Gate Sign-Off:** Present the final spec artifact with `RequestFeedback: true`. Wait for explicit user approval ("Proceed") before writing implementation code.

### Gate 2: Milestone Demonstration (Composite Tasks)
- **Mid-Flight Checkpoint:** For composite tasks spanning $\ge 3$ components or visual UI layouts, halt at logical milestones (e.g. skeleton + layout ready, before reactive scripting).
- **Presentation:** Present an intermediate diff, DOM preview, or APCA contrast audit to verify direction before completing remaining slices.

### Gate 3: Proof-of-Verification Presentation
- **Evidence Before Assertion:** Before declaring completion, present the **Acceptance Criteria Verification Table**:

| Criterion ID | Requirement Description | Verification Evidence | Status |
| :--- | :--- | :--- | :--- |
| **AC-01** | *[Description]* | *[Harness command / Test output log]* | **PASSED** |
| **AC-02** | *[Description]* | *[Harness command / Test output log]* | **PASSED** |

---

## 3. The Embedded CI/CD Self-Healing Loop

Verification is an integrated execution gate, not a post-hoc ceremony:
1. **Pre-Tool Hook Shielding:** High-volume CLI tools are intercepted and shielded to disk via `.agents/scripts/run-shielded.ps1`.
2. **Continuous 4-Stage Harness:** Every modification is validated against:
   - *Stage 1:* Docs-as-Code & Memory Integrity (`audit-memory.ps1`).
   - *Stage 2:* Micro-Modularity & Anti-Slop Audit (`audit-code.ps1`, `audit-restraint.ps1`).
   - *Stage 3:* Subsystem Test Matrix (Landing, MCP, Platform).
   - *Stage 4:* Documentation Drift & Reviewer Ping-Pong (`run-pingpong.ps1`, `release-audit.ps1`).
3. **Autonomous Self-Healing (`--SelfHeal`):**
   - On harness failure, auto-healing resolves SemVer drift and pointer boundaries via `.agents/scripts/self-heal.ps1`.
   - On code test failures, dispatch `defect-fixer` in `Workspace: "branch"` (capped at 2 retries) before escalating to the user.
4. **Git Pre-Commit Gate:** `.git/hooks/pre-commit` mandates a passing 4-stage harness run before any commit is accepted.
