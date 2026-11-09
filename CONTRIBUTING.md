# Contributing to AGI

Thank you for contributing to `LoveBitterMuffin/agi`. Every change must preserve deterministic quality, minimal code footprint, and cross-platform integrity.

## 1. Spec-First Workflow

1. **Gate 0 Alignment:** Non-trivial features, refactors, or UI changes must clarify architectural options before editing code.
2. **Formal Specification (`SPEC-YYYY-NNN`):** Define testable acceptance criteria (`AC-01`, `AC-02`, ...) and get sign-off before implementing changes.
3. **Proof of Verification:** Verify every criterion with executed test/audit outputs prior to opening a pull request.

## 2. Ponytail 7-Rung Engineering Restraint

*"The best code is the code you never wrote."* Stop at the lowest rung that solves the problem:

1. **YAGNI:** Reject speculative abstractions and unused options.
2. **Re-use:** Search existing modules, hooks, and `scripts/` before adding new utilities.
3. **Stdlib:** Prefer Node.js, Python, and PowerShell standard libraries.
4. **Platform:** Leverage native OS and shell primitives.
5. **Dependencies:** Use existing dependencies before introducing new ones.
6. **Minimal Expression:** Keep logic as a concise, single-purpose function or pipeline.
7. **Minimum Code:** Write only the minimal working implementation plus targeted test coverage.

## 3. Micro-Modularity Law

- **File Limit:** New source files must not exceed **150 lines** (warning threshold at 100 lines). For legacy files over 150 lines, extract new features into adjacent micro-modules rather than expanding the monolith.
- **Function Scope:** Maximum **30 lines** per function or method.
- **Nesting Depth:** Maximum **3 levels** of indentation; flatten control flow with early returns.
- **Clean Hygiene:** No empty `catch`/`except: pass` blocks, no commented-out dead code, no `TODO`/`FIXME` backlog comments, and no tautological comments.

## 4. Local Verification

Run the cross-platform test and validation suite from the repository root:

```bash
node --test tests/tool-chain-hooks.test.mjs tests/agi-manifest.test.mjs
node hooks/audit-restraint.mjs hooks
node scripts/verify-ui.mjs
PYTHONIOENCODING=utf-8 python scripts/session_manager.py status .
agy plugin validate --strict
```

On Windows, also run the PowerShell governance audits:

```powershell
pwsh -NoProfile -File scripts/audit-code.ps1
pwsh -NoProfile -File scripts/audit-restraint.ps1 -Strict
pwsh -NoProfile -File scripts/audit-memory.ps1
pwsh -NoProfile -File scripts/triage-task.ps1 -Task "CI" -Json
pwsh -NoProfile -File scripts/estimate-complexity.ps1 -Description "CI" -JsonOutput
```

## 5. Pull Request Hygiene

- **Zero Python bytecode:** No `__pycache__/` directories or `*.pyc` files in the tree.
- **Zero secrets:** Never commit `.env`, `.env.*`, API keys, tokens, or credentials.
- **Clean runtime state:** Ensure `memory/harness_incidents.json` remains clean (`[]`) and no `scratch/` or `*.log` artifacts are committed.
- **Line endings:** Preserve LF line endings per `.gitattributes`.
- **Green CI:** Both `linux-verify` and `windows-harness` workflows must pass.
