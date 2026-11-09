---
trigger: always_on
description: Strict Code Standards, Micro-Modularity Law, and Anti-Slop Code Hygiene Protocol.
---

# 04: Code Standards, Micro-Modularity Law & Anti-Slop Protocol

## 1. The Micro-Modularity Law (Hard Line Limits)

Frontier AI agents easily produce bloated, multi-hundred-line monolithic classes that saturate context and breed subtle bugs. In this repository, code must be decomposed into atomic, single-responsibility micro-modules.

### Hard Thresholds for Production Code (`src/**`):
1. **New Files Ceiling:** Any newly created code file (`.ts`, `.js`, `.py`, `.vue`, `.html`) MUST NOT exceed **150 lines**.
2. **Warning Threshold:** At **100 lines**, consider decomposing into sub-components or utility micro-modules.
3. **Function Scope:** Functions and methods MUST NOT exceed **30 lines**. If a function exceeds 30 lines, extract helper functions or pipeline stages.
4. **Cognitive Nesting:** Maximum **3 levels** of indentation. Flatten deeply nested `if/else/try` structures using early returns and guard clauses.
5. **Legacy Ratchet Rule (Boy Scout Principle):** When modifying existing legacy files exceeding 150 lines:
   - Do NOT add bulk logic into the monolith.
   - Extract the new capability into an adjacent micro-module (`src/.../modules/<feature>.ts`) and import it.
   - The file size of legacy files may only decrease or stay neutral, never expand.

---

## 2. Anti-Slop Code Comment Hygiene

Comments must explain non-obvious business/domain **WHY**, never the syntactic **WHAT**.

### Strictly Prohibited:
- ❌ **Tautological Comments:**
  ```typescript
  // BAD: AI Slop
  // Function to initialize user
  function initUser() { ... }
  // Loop through items
  for (const item of items) { ... }
  // Return the result
  return result;
  ```
- ❌ **Commented-Out Dead Code:** Never leave commented-out code blocks (`// const oldVal = 123;`). Git history is the single source of truth.
- ❌ **Speculative In-Code Backlog:** Never litter code with `// TODO: implement later` or `// FIXME: add error handling`. All requirements must reside in formal `SPEC-YYYY-NNN` or be implemented immediately.
- ❌ **User-Facing Telemetry & Fake Audit Stamps (Rule R-41):** Never generate synthetic audit badges (`APCA AAA PASS`, `WCAG 2.2 AAA PASS`, `APCA Lc 94.0 OPTIMAL`), node status pulses (`STATUS // NODE-PULSE`), artificial version stamps (`v2.4.0 // SPEC`, `HEX-AERO-DS // v2.4.0`), slash separators (`...//...`), corner crosshairs (`+`, `+`), or pseudo-code component labels (`CARD // CHAMFER-16`).
- ❌ **Hallucinated Domain Claims:** Never invent unverified institutional affiliations, accreditations, or fake partner universities (e.g. "по стандартам НИЯУ МИФИ и МГТУ им. Баумана").
- ✅ **Mandatory Structured Placeholders:** If data is missing and unconfirmed in `src/data/`, always use explicit markers: `[Плейсхолдер: ...]`.


### Permitted & Required:
- ✅ **Mathematical / Invariant rationale:** Explaining non-obvious formulas (e.g. APCA contrast constants, Golden Ratio rhythm calculations).
- ✅ **Security / Concurrency boundaries:** Explaining mutexes, race condition preventions, or cryptographic sanitization.

---

## 3. Strict Typing & Explicit Contracts

1. **TypeScript (`noImplicitAny`):**
   - No untyped `any`. Use strict interfaces, union types, or `unknown` with runtime type narrowing.
   - Explicit parameter types and explicit return types on all exported functions.
   - When a function accepts more than 3 arguments, bundle them into a typed configuration object:
     ```typescript
     // GOOD: Parameter Object
     interface RenderConfig {
       width: number;
       height: number;
       scale?: number;
       dof?: boolean;
     }
     function renderScene(config: RenderConfig): CanvasResult { ... }
     ```
2. **Python (PEP 484/585/604 Type Annotations):**
   - Mandatory type hints on all public signatures (`def execute(cmd: str, timeout_sec: float = 30.0) -> ExecutionResult:`).
   - No untyped `*args, **kwargs` as a shortcut for domain parameters. Use `@dataclass(frozen=True)` or typed models.

---

## 4. Defensive Resilience & Zero Silent Failures

1. **Ban on Silent Catching:**
   - Empty catch/except blocks are fatal violations:
     ```typescript
     // FORBIDDEN:
     try { ... } catch (e) {}
     ```
     ```python
     # FORBIDDEN:
     try: ...
     except: pass
     ```
   - All caught errors must either be handled with fallback logic, logged with context, or re-thrown as typed domain errors.
2. **Deterministic Timeouts:**
   - Any network fetch, subprocess command, IPC call, or database query MUST include an explicit timeout. Unbounded hanging operations are forbidden.
3. **Structured Diagnostics:**
   - Error messages must provide actionable telemetry: what operation failed, which entity/path was targeted, and the error code/reason.

---

## 5. Machine-Checked Test Requirement (TDD Contract)

1. Any file containing branching logic, loops, calculations, parsers, or access control MUST have at least one machine-checked test.
2. Pure data schemas and static type definitions without logic are exempt.
3. Tests must execute in $<200\text{ ms}$ per unit and operate with zero side-effects on shared state.

---

## 6. Automated Verification

Compliance is verified automatically at every commit and harness run via:
- `.agents/scripts/audit-code.ps1` (Hard line bounds, empty catches, comment slop)
- `.agents/scripts/audit-restraint.ps1` (Ponytail 7-rung ladder, dependency checks)
- `.agents/harness/run-harness.ps1` (Stage 2 Quality Gate)
