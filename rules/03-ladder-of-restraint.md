---
trigger: always_on
description: The 7-Rung Ladder of Restraint (Ponytail Pattern) for eliminating AI over-engineering and code bloat.
---

# 03: The Ladder of Restraint & Anti-Bloat Protocol (Ponytail Pattern)

## 1. Core Engineering Doctrine
*"The best code is the code you never wrote. Lazy about the solution, never about reading."*

Frontier AI agents have a bias toward generating gratuitous boilerplate, custom abstractions, redundant helpers, and premature generic architectures. This inflates token budgets, slows response times, and multiplies maintenance debt.

Before generating or modifying any code in `src/**` or `.agents/**`, the agent MUST evaluate the **Ladder of Restraint** and stop at the lowest rung that satisfies the requirement:

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

## 2. Non-Negotiable Rung Verification Rules
1. **Never Reinvent the Standard Library:** Do not write custom deep-clone, date parsers, string padders, argument serializers, or hash utilities if the runtime (Node.js, Python, PowerShell, Go) provides them.
2. **Never Add Dependencies for Trivial Tasks:** Do not install third-party packages for operations achievable in <10 lines of standard library code.
3. **Lazy, Never Negligent:** The ladder applies to *solution design*, NEVER to safety, trust boundaries, data integrity, or testing:
   - Security checks, parameter sanitization, rate limits, and error handling CANNOT be skipped.
   - Any logic containing a branch, a loop, a parser, money, or access control MUST be verified by at least one machine-checked test.
4. **Token Budget Restraint:** Aim for $-40\%$ to $-50\%$ code volume relative to naive solutions. Prefer concise, readable, idiomatic code over bloated multi-file abstractions.
