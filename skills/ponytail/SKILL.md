---
name: ponytail
description: Official DietrichGebert/ponytail protocol, Full Senior level engineering restraint, 7-rung ladder, YAGNI, and anti-bloat code review.
when_to_use: "Always active during code generation, architectural scoping, library evaluation, and code review."
allowed-tools: Read, Write, Edit, Grep
version: 1.0.0
priority: CRITICAL
---

# Ponytail Protocol — Full Senior Engineering Restraint

> **Core Credo:** *"The best code is the code you never wrote. Lazy about the solution, never about reading."*

The Ponytail Protocol enforces ruthless engineering discipline: eliminate premature generic architectures, speculative helpers, redundant abstractions, and gratuitous dependencies before a single line of production code is kept.

---

## 1. The 7-Rung Ladder of Restraint

Before writing, generating, or modifying code in `src/**` or `.agents/**`, every agent MUST evaluate this ladder sequentially from top to bottom and stop at the **lowest rung that satisfies the requirement**:

```
[Rung 1: YAGNI] ─────────── Does this need to exist at all? (Challenge premise / avoid code)
       │
[Rung 2: Re-use] ────────── Is this already in the codebase? (Inspect symbol map / grep)
       │
[Rung 3: Stdlib] ────────── Does the language standard library already provide it?
       │
[Rung 4: Platform] ──────── Can the host OS / shell / runtime solve it natively?
       │
[Rung 5: Dependencies] ──── Can an already installed dependency solve it?
       │
[Rung 6: Minimal Expression] Can it be expressed in a single clean function or pipeline?
       │
[Rung 7: Minimum Code] ──── Only then: write the minimum code that works, + 1 targeted test.
```

### Rung Operational Definitions

| Rung | Evaluation Question | Senior Action |
|:---|:---|:---|
| **1. YAGNI** | Is this speculative feature or generalized flexibility strictly needed right now? | Reject or delete. If requirement is unconfirmed, use explicit placeholder or ask via Gate 1.X. |
| **2. Re-use** | Does an identical or adaptable function/component already exist in the codebase? | Grep AST/symbols. Import or refactor existing module rather than duplicating logic. |
| **3. Stdlib** | Does Node.js, Web APIs, Python, Go, or PowerShell built-ins provide this? | Never write custom deep-clone (`structuredClone`), URL parsers (`URL`), UUIDs (`crypto.randomUUID`), or string padders. |
| **4. Platform** | Can the OS, shell, or runtime platform handle this directly? | Leverage OS streams, child process pipes, native file system primitives instead of bloated npm/pip wrappers. |
| **5. Dependencies** | Does an already installed package solve this problem? | Check `package.json` / `pyproject.toml` before adding ANY new third-party dependency. Adding new dependencies requires Gate 1.X sign-off. |
| **6. Minimal Expression** | Can this requirement be satisfied in a single clean function or pipeline? | Write a pure function or 5–15 line pipeline. Reject classes, factories, and abstraction layers for single-use operations. |
| **7. Minimum Code** | Code must be written from scratch? | Write the absolute minimum code that satisfies the Acceptance Criteria, accompanied by exactly 1 machine-checked unit test. |

---

## 2. Senior Anti-Bloat Code Standards

1. **Volume Reduction Target:** Target **-40% to -50%** code volume relative to naive LLM generations.
2. **Micro-Modularity Law:**
   - Production code files: **<= 150 lines** ceiling.
   - Functions / methods: **<= 30 lines** ceiling.
   - Indentation depth: **<= 3 levels**. Flatten via early returns and guard clauses.
3. **Zero Speculative Boilerplate:**
   - ❌ No factory-factories, abstract base classes for single implementations, or empty interfaces.
   - ❌ No manual DTO-to-entity mappers when structural typing or typed parameters suffice.
   - ❌ No premature configuration layers or environment variables for hardcoded constants.
4. **Anti-Slop Comment Hygiene:**
   - Comments must explain non-obvious business/domain **WHY**, never the syntactic **WHAT**.
   - ❌ Zero tautological comments (`// initialize user`, `// return result`).
   - ❌ Zero commented-out dead code.
   - ❌ Zero user-facing telemetry, fake audit badges, or pseudo-code labels (Rule R-41).

---

## 3. Subagent & PR Review Checklist

When acting as `code-reviewer` or evaluating subagent code:

- [ ] **Rung Check:** Was the lowest possible rung used? Did the author reinvent any standard library API?
- [ ] **Line Bound:** Does any new file exceed 150 lines? Does any function exceed 30 lines?
- [ ] **Nesting Check:** Is nesting strictly <= 3 levels with guard clauses?
- [ ] **Dependency Audit:** Were any unnecessary packages installed?
- [ ] **Test Proof:** Is there a machine-checked test validating every branch/condition?
- [ ] **Slop Scan:** Are comments strictly explaining invariants/math, free of tautological filler?
