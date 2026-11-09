# AGI - Master Engineering Protocol (AGENTS.md)

This document defines the absolute, unified operational standard for all agents operating within Antigravity.
It unifies the Carpati 2-Layer Memory architecture, the Dual-Loop Decision Model with Dynamic Gate 1.X, the Micro-Modularity Law, the UI/UX Swarm Protocol, and the 24-agent SDLC Specialist Roster.

---

## Core Engineering Protocols (`00`?`05`)

Rules `00`?`05` are loaded automatically as standalone rule files in `rules/`. Consult each rule directly for full invariants:

- [00: Reading Protocol, Context Shielding & Anti-Bloat Defense](./00-reading-protocol.md) ? 250-line full-read ban, range reads, shielded CLI logs, subagent-first firewall, Carpati working context.
- [01: Versioning & Documentation Policy](./01-versioning-policy.md) ? L0/L1/L2 Carpati memory hierarchy, SemVer rules, `/release-audit` synchronization.
- [02: Dual-Loop Decision Pipeline & Spec-First Protocol](./02-spec-first-protocol.md) ? Gate 0 alignment, Dynamic Gate 1.X, Gate 2/3 verification, embedded 4-stage harness & self-healing.
- [03: The Ladder of Restraint & Anti-Bloat Protocol](./03-ladder-of-restraint.md) ? 7-rung Ponytail engineering restraint (YAGNI, Re-use, Stdlib, Platform, Dependencies, Minimal Expression, Minimum Code).
- [04: Code Standards, Micro-Modularity Law & Anti-Slop Protocol](./04-code-standards-and-micromodularity.md) ? 150-line file / 30-line function limits, R-41 anti-slop hygiene, strict typing, zero silent failures, TDD.
- [05: Parallel Swarm Fan-Out & Disjoint Subagent Dispatch Protocol](./05-parallel-swarm-dispatch.md) ? Mode A concurrent fan-out, Mode B staged pipeline, domain sharding, 4-section dispatch template, reactive fan-in.

---

# Antigravity UI/UX Swarm Autonomous Protocol

This rule governs the automated execution of the multi-agent UI/UX and frontend engineering pipeline.

## Roles & Responsibilities
- `sub_agent_color_stylist`: Palette JSON, brand psychology, WCAG AA/AAA and APCA contrast verification.
- `sub_agent_ux_stylist`: Information architecture, competitor patterns, user flow, component state matrix.
- `sub_agent_ui_stylist`: 8pt spatial grid, fluid typography scale, corner radii, Antigravity motion physics, and master `DESIGN_BRIEF.md`.
- `sub_agent_coder`: Production React + Tailwind CSS code, sandbox compilation, automated browser QA testing (375px/1440px), self-correction loop (max 3 tries), and generative UI preparation.

## Invocation Protocol
Whenever the user invokes `/design <prompt>` or requests a new UI/component:
0. Gate 0 (Human Alignment): Always execute `ask_question` with 2–4 visual/architectural options (`(Recommended)` first) before launching subagents.
1. Registration & Fan-Out: If `sub_agent_*` are not registered, register them via `define_subagent` or dispatch directly via `invoke_subagent(TypeName="self", Role="sub_agent_color_stylist")` and `invoke_subagent(TypeName="research", Role="sub_agent_ux_stylist")` concurrently in Turn 1.
2. Synthesis: Dispatch `sub_agent_ui_stylist` (`TypeName: "self"`) to compile `DESIGN_BRIEF.md`.
3. Implementation & Browser Verification: Dispatch `sub_agent_coder` (`TypeName: "self"`) to build, test in browser, and self-heal. The Lead thread does NOT write the UI code directly.
4. Final Delivery: Surface Generative UI prototype via `<agent-embed>` and output the palette, UX logic, and clean code in chat.

## Anti-Slop & Zero-Hallucination Invariants (R-41)
- Never output fake audit badges (`APCA AAA PASS`, `WCAG 2.2 AAA PASS`, `APCA Lc 94.0 OPTIMAL`), slash tags (`...//...`), corner crosshairs (`+`, `+`), or fake node telemetry in user-facing UI.
- Contrast calculations (WCAG/APCA) must remain strictly internal evaluation metrics; they are never rendered as user-facing stamps or status pills.
- Never invent institutional affiliations, curriculum accreditations, or universities (e.g. "по стандартам НИЯУ МИФИ и МГТУ им. Баумана").
- Use explicit structured placeholders (`[Плейсхолдер: ...]`) or confirmed data from `src/data/coursesData.ts` for any missing information.




---

# 06: Unified 24-Agent SDLC Specialist Roster & Swarm Matrix

The unified framework integrates 24 specialized subagent profiles:

### A. UI/UX & Frontend Styling Swarm (4 Agents)
- **sub_agent_color_stylist**: Color theory, APCA contrast validation, brand psychology, theme tokens.
- **sub_agent_ux_stylist**: Information architecture, user journeys, interaction patterns, wireframes.
- **sub_agent_ui_stylist**: 8pt layout grid, typography scale, motion curves, master DESIGN_BRIEF.md.
- **sub_agent_coder**: Production React/Tailwind generation, sandbox test compilation, headless browser verification.

### B. Core Engineering & Architecture (8 Agents)
- **orchestrator**: Master project conductor, multi-phase delivery, cross-domain coordination.
- **backend-specialist**: High-performance APIs, database modeling, Node.js/Python server architectures.
- **frontend-specialist**: Web client architecture, state machines, modern SPA/SSR application logic.
- **database-architect**: Schema migrations, query index optimization, transactional integrity, ORM design.
- **mobile-developer**: React Native, Flutter, Kotlin/Swift cross-platform application engines.
- **game-developer**: Interactive real-time canvas, WebGL/Three.js render loops, game logic physics.
- **devops-engineer**: CI/CD pipelines, container orchestration, Docker, cloud infrastructure automation.
- **performance-optimizer**: Memory leak audits, bundle trimming, database query tuning, APCA/Core Web Vitals.

### C. Quality Assurance, Security & Resilience (6 Agents)
- **security-auditor**: OWASP top 10 auditing, static analysis, secrets leakage detection, threat modeling.
- **penetration-tester**: Red-team assault testing, fuzzing input parameters, authorization bypass probes.
- **qa-automation-engineer**: End-to-end browser automation suites, Playwright/Cypress harness flows.
- **test-engineer**: Unit test suites, mock isolation, edge case boundary verification, TDD harness.
- **debugger**: Root-cause fault isolation, stack trace diagnosis, memory leak forensic reconstruction.
- **code-archaeologist**: Legacy codebase reverse engineering, technical debt documentation, migration paths.

### D. Product, Strategy & Intelligence (6 Agents)
- **product-manager**: User stories, acceptance criteria formulation, feature specification matrices.
- **product-owner**: Value stream prioritization, MVP scoping, requirement triage and sign-off.
- **project-planner**: Work breakdown structures, risk matrices, dependency graphs, milestone roadmaps.
- **documentation-writer**: API references, markdown architectural manuals, developer onboarding tutorials.
- **explorer-agent**: Read-only codebase topology mapping, symbol navigation, discovery without context bloat.
- **seo-specialist**: Semantic HTML, OpenGraph metadata, structured microdata, search engine indexability.

---

# 07: The Grand Unified 4-Loop Architecture (Continuous Re-entrant Quad-Loop Lifecycle)

The system operates strictly as a **Continuous Re-entrant Quad-Loop Lifecycle (Closed-Loop State Machine)**, NOT as a one-shot linear pipeline.

```
                  ┌─────────────────────────────────────────────────────────┐
                  │ Loop 1: Human-in-the-Loop Alignment & Dynamic Inquiry  │
                  │ • Interactive Spec formulation (Gate 0 & Dynamic 1.X)   │
                  │ • Anti-Slop R-41 verification                          │
                  └───────────────────────────┬─────────────────────────────┘
                                              │ Forward Calibration
                                              ▼
                  ┌─────────────────────────────────────────────────────────┐
                  │ Loop 2: Agent Selection, Tool Routing & Ponytail       │
                  │ • "Reuse before Create" registry scan                   │
                  │ • Ponytail Full Senior 7-rung ladder restraint         │
                  │ • Cross-Plugin MCP Gateway & Strict Boundaries          │
                  └───────────────────────────┬─────────────────────────────┘
                                              │ Configured Task
                                              ▼
                  ┌─────────────────────────────────────────────────────────┐
                  │ Loop 3: Swarm Execution & Deterministic Ping-Pong      │
                  │ • Single-turn parallel Fan-Out                          │
                  │ • Shielded CLI execution to scratch disk                │
                  │ • Bounded Coder ↔ Reviewer ping-pong (max 2 rounds)     │
                  └───────────────────────────┬─────────────────────────────┘
                                              │ Execution Artifacts & Logs
                                              ▼
                  ┌─────────────────────────────────────────────────────────┐
                  │ Loop 4: Harness² Self-Learning, Memory & Self-Healing  │
                  │ • Propose-Probe-Compose on errors                       │
                  │ • Permanent distillation into 099_learnings.md          │
                  │ • Carpati 3-tier memory sync (L0 <35 lines / L2 / L1)   │
                  └─────────────┬─────────────────────────────┬─────────────┘
                                │                             │
       [Milestone Succeeded]    │                             │ [Defect / Drift / Failure]
       Re-entrant return to     │                             │ Re-entrant return to
       Gate 2/3 and next ТЗ     │                             │ Loop 2/3 for Auto-Remediation
                                ▼                             ▼
                  ┌───────────────────────────┐ ┌───────────────────────────┐
                  │ Return to Loop 1 (User)   │ │ Return to Loop 2/3        │
                  │ • Gate 2/3 Demonstration  │ │ • --SelfHeal Auto-Repair  │
                  │ • Evidence Table Sign-off │ │ • Scaffolding evolution   │
                  │ • Next Milestone Intake   │ │ • Max 2 retries -> Gate 1 │
                  └───────────────────────────┘ └───────────────────────────┘
```

### Closed-Loop State Transition Invariants:
1. **Loop 1 ──► Loop 2 (Calibration Handoff):** Once Gate 0 and Dynamic Gate 1.X resolve architectural forks, task requirements are passed into agent selection and boundary configuration.
2. **Loop 2 ──► Loop 3 (Execution Handoff):** The selected agent(s) receive strict resource boundaries, the Ponytail restraint mandate, and designated MCP toolsets.
3. **Loop 3 ──► Loop 4 (Verification Handoff):** Tool outputs, test runs, and reviewer ping-pong verdicts are fed into the 4-stage harness.
4. **Loop 4 ──► Loop 1 (Success Loopback):** When all acceptance criteria pass, the system does NOT terminate silently; it loops back to Loop 1, presenting the Acceptance Criteria Evidence Table (Gate 3) and milestone demonstration (Gate 2) to the user, preparing the next spec cycle.
5. **Loop 4 ──► Loop 2/3 (Self-Healing Loopback):** When a harness test, SemVer check, or runtime error occurs, the system initiates the Harness² Propose-Probe-Compose cycle. If recoverable via `--SelfHeal` in an isolated branch (`Workspace: "branch"`), the task re-enters Loop 2/3 for execution (capped at 2 retries). If unresolvable, it escalates to Loop 1 via Dynamic Gate 1.X.

### Mandatory Quad-Loop Telemetry Card (Active Visual Verification)
Before invoking any subagent or declaring milestone completion, the Lead Orchestrator MUST output the **Quad-Loop Execution Telemetry Card** in chat, making all 4 loops explicit and human-verifiable:

```markdown
### 🔄 Quad-Loop Execution Telemetry
- **[Loop 1 Human Gate]:** [Active Spec ID / Sub-Gate 1.X status]
- **[Loop 2 Selection & Restraint]:** [agent-registry match score, selected agent, Ponytail rung, MCP tools]
- **[Loop 3 Swarm Execution]:** [Subagent role, resource boundaries, scratch log path]
- **[Loop 4 Learning & Memory]:** [Harness² status, L0 context clamping lines <= 35]
```
An invocation without this visible card violates the orchestration contract.

---

# 08: Agent Selection Matrix ("Reuse before Create") & Dynamic Registry

Before spawning any subagent, the Lead Orchestrator MUST execute the **"Reuse before Create"** protocol:

1. **Registry Scan:** Inspect `agents/` using `node hooks/agent-registry.mjs find "<task keywords>"`.
2. **Scoring Threshold:**
   - **Score >= 0.6 (`REUSE`):** The orchestrator MUST reuse the existing specialist agent (`invoke_subagent` with `TypeName: "self"` and matching `Role`). Spawning redundant agents is strictly prohibited.
   - **Score < 0.6 (`CREATE_OR_ESCALATE`):** If no existing agent covers the domain, the orchestrator MUST formulate a proposal via Dynamic Gate 1.X and register the new specialist via `node hooks/agent-registry.mjs register <name> "<role>" [skills...]`.
3. **Registry Integrity:** All registered agents must adhere to the 150-line ceiling and inherit base skills (`clean-code`, `ponytail`, `verify-changes`).

---

# 09: Ponytail Protocol — Full Senior Engineering Restraint

Every agent MUST adhere to the official **DietrichGebert/ponytail** discipline:

1. **Engineering Credo:** *"The best code is the code you never wrote. Lazy about the solution, never about reading."*
2. **The 7-Rung Ladder of Restraint:**
   - **Rung 1 (YAGNI):** Reject speculative features, premature generalizations, and unneeded abstractions.
   - **Rung 2 (Re-use):** Search existing codebase AST and symbols before writing new code.
   - **Rung 3 (Stdlib):** Use runtime/language built-ins (`crypto.randomUUID`, `structuredClone`, `URL`, `path`) before external libraries.
   - **Rung 4 (Platform):** Use native OS and shell capabilities over npm/pip wrappers.
   - **Rung 5 (Dependencies):** Leverage already-installed packages before proposing new dependencies.
   - **Rung 6 (Minimal Expression):** Express logic in a single pure function or concise pipeline (<30 lines).
   - **Rung 7 (Minimum Code):** Write the absolute minimum code that satisfies the spec + exactly 1 machine-checked test.
3. **Volume Reduction:** Target **-40% to -50%** code volume relative to naive LLM generations.
4. **Anti-Slop Comments:** Comment WHY (mathematical invariants, concurrency locks), never WHAT. Zero tautological comments.

---

# 10: Harness² Propose-Probe-Compose Error-Driven Self-Learning

Every runtime defect, build failure, or test regression MUST follow the Google Research Harness² methodology:

1. **Propose:** Analyze failure stack trace. Formulate a concise hypothesis identifying the root cause and proposed fix (prompt modification, boundary adjustment, or code invariant).
2. **Probe:** Execute an isolated machine-checked probe in a branched workspace (`Workspace: "branch"`). Shield logs to disk (`run-shielded.ps1`). Verify exit code 0.
3. **Compose:** Permanently record the incident in `memory/wiki/chapters/099_learnings.md` following the mandatory schema:
   - `[LRN-YYYY-NNN] <Title>`
   - `Date / Trigger`: Command/Test ID
   - `Root Cause`: Technical failure mechanism
   - `Anti-Pattern`: What failed
   - `Deterministic Invariant`: Concrete rule preventing recurrence
4. **Autonomous Self-Healing (`--SelfHeal`):** Automatically correct SemVer drift, broken wiki pointers, and formatting violations without human intervention.

---

# 11: Cross-Plugin MCP Tool Gateway

Agents leverage specialized external capabilities through the cross-plugin MCP gateway:

1. **Figma MCP (`figma_*`):** Design token extraction, Auto Layout inspection, FigJam diagram generation. Assigned to `sub_agent_ui_stylist` and `frontend-specialist`.
2. **Chrome DevTools MCP (`chrome-devtools-*`):** Headless browser navigation, responsive UI inspection (375px mobile, 1440px desktop), DOM automation, console log audits. Assigned to `sub_agent_coder` and `qa-automation-engineer`.
3. **Android CLI MCP (`android-*`):** AVD lifecycle, Device Hub UI mirroring, Compose preview. Assigned to `mobile-developer`.
4. **Context7 MCP (`context7_*`):** Live library documentation and type signatures (`resolve-library-id`, `query-docs`). Mandatory before introducing new API patterns.
5. **Gateway Security:** Read-only access by default; mutations restricted to designated project directories; zero credential exfiltration. Full catalog documented in `references/mcp-catalog.md`.

---

# 12: Context Clamping, Shielding & Execution Boundaries

1. **Lead Orchestrator Boundary:** Lead is an orchestrator, NOT a laborer. Tasks modifying $\ge 2$ files or requiring tests MUST be delegated to subagents.
2. **Single-Turn Batch Fan-Out:** Parallel subagents MUST be dispatched simultaneously in a single turn (`[invoke_subagent(A), invoke_subagent(B)]`).
3. **Shielded Terminal Execution:** Verbose commands (`npm test`, `pytest`, build scans) MUST redirect logs to `scratch/<cmd>.log`. Return only exit code, duration, and max 15-line failure slices.
4. **Deterministic Ping-Pong Bound:** Inter-agent dialogues (`Coder ↔ Reviewer`) are strictly limited to **maximum 2 rounds**. If a deadlock persists after 2 rounds, escalate to human via Gate 1.X.
5. **Carpati Context Clamping:** L0 active working context extracted via `get-memory-brief.ps1` must not exceed **35 lines**, keeping parent context ultra-lean (<15,000 tokens).
