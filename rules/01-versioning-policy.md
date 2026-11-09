---
trigger: always_on
description: Semantic versioning policy, chapter synchronization, and release audit standards.
---

# 01: Versioning & Documentation Policy

## 1. Three-Tier Memory Hierarchy & Compilation Architecture (L0 / L1 / L2)
- **L0 Runtime Working Cache (`MEMORY.md` / `ActiveSprintLog.md`):**
  Ultra-compact runtime context (<35 lines) containing active sprint pointers, immediate constraints, and domain invariants. Compiled dynamically from Layer 2 wiki chapters; never stores monolithic logs or raw transcripts.
- **Layer 2 (Compiled Wiki - Persistent Knowledge Base):**
  Synthesized domain knowledge, architectural contracts, and operational guidelines stored in `memory/wiki/chapters/*.md`. Version-controlled via SemVer. Replaces verbose dumps with lossless pointers into Layer 1.
- **Layer 1 (Raw Vault - Immutable Ground Truth):**
  Immutable historical intake, raw user specifications, transcripts, and telemetry stored in `memory/raw/vault/RAW-YYYY-NNN_<slug>.md`. Serves as permanent audit trail and re-compilation source.
- **Lossless Traceability Flow:**
  Information flows unidirectionally from intake to execution (`L1 Raw Vault -> L2 Compiled Wiki -> L0 Runtime Cache`), while references point upstream (`L0 -> L2 -> L1: lines X-Y`). Unbounded transcripts or raw tables must never leak into L0 or L2.

## 2. Semantic Versioning (SemVer)
- Every wiki chapter contains a YAML frontmatter header specifying `version` (`MAJOR.MINOR.PATCH`) and `status`.
- **MAJOR:** Breaking architectural shift, module deprecation, or total redesign of a core domain contract.
- **MINOR:** New feature additions, new subsystem capabilities, or expanded public interfaces.
- **PATCH:** Bugfixes, doc clarifications, or minor line pointer adjustments.

## 3. Synchronization & Release Audits
- Code changes in `src/` must be paired with corresponding updates in `memory/wiki/chapters/`.
- No code release is considered complete without executing the `/release-audit` workflow:
  1. `git diff` inspection against documentation.
  2. SemVer recalculation.
  3. `memory/Index.md` mapping update.
  4. Entry logged in `memory/logs/CHANGELOG.md`.
  5. Log compaction of `memory/logs/ActiveSprintLog.md` if exceeding 180 lines.
