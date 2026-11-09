# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-11-09

### Added
- **Hybrid Quad-Loop Telemetry Guard (`hooks/quad-loop-guard.mjs`):**
  - `PreInvocation` (`--event pre-invocation`) inspects the `256 KB` tail of the active turn transcript and injects live `ephemeralMessage` metrics (`chainCalls`, `incidents`, `stopRetries`, `subagentDenies`) via `injectSteps`, plus a single-shot `systemMessage.metadata.user_markdown` fallback card if a prior `Stop` retry already occurred.
  - `PreToolUse` (`invoke_subagent` via `hooks/validate-tool-call.mjs`) enforces presence of the `### 🔄 Quad-Loop Execution Telemetry` card (`[Loop 1`..`[Loop 4`) in the active turn transcript, denying up to 2 times per turn (`decision: "deny"`, exit `2`) and failing open when no transcript is available.
  - `Stop` (`--event stop`) enforces a single `NO_TOOL_CALL` retry (`decision: "continue"`) when work occurred without a telemetry card, while preserving active turn counters across `PreInvocation` (`hooks/reset-tool-chain.mjs`, `hooks/tool-chain-state.mjs`) and resetting cleanly on terminal `Stop`.
- **Quad-Loop Telemetry Test Suite (`tests/quad-loop-telemetry.test.mjs`):** Added 5 unit and CLI integration tests verifying `SessionStart` `injectSteps`, 256 KB transcript tail slicing, `PreInvocation` live metrics & `user_markdown` fallback, `PreToolUse` `invoke_subagent` gating, and `Stop` single-retry enforcement (`13/13` passing across all 3 test files).

### Changed
- **SessionStart Official Contract (`hooks/session-start.mjs`):** Aligned stdout payload with the `injectSteps` schema (`AGI v1.0.1 active`, `24 SDLC agents`, `66 skills loaded`) and bumped `plugin.json` version to `1.0.1`.
- **Governance Rules & Documentation (`rules/00-reading-protocol.md`, `rules/05-parallel-swarm-dispatch.md`, `README.md`, `README.ru.md`):** Documented the Quad-Loop Execution Telemetry gate, updated `"Adaptive Triage"` to `"Adaptive Task Triage"` (`"адаптивный триаж задач"` in `README.ru.md`), and updated CI/Release workflows (`.github/workflows/ci.yml`, `.github/workflows/release.yml`) to execute `tests/quad-loop-telemetry.test.mjs`.

## [1.0.0] - 2026-11-09

### Added
- **Plugin Manifest & Branding:** Initial open-source release of `agi` (`plugin.json` with `name: agi`, `displayName: AGI`, `version: 1.0.0`), geometric vector icon at `assets/logo.svg`, and Antigravity Marketplace `agy plugin validate --strict` compliance.
- **Skills Catalog (`66` skills):** Complete set of engineering, UI/UX, architecture, QA, security, and memory skills, including migrated slash-workflows.
- **SDLC Specialist Roster (`24` agents):** Specialized subagent profiles across UI/UX Styling Swarm, Core Engineering & Architecture, Quality Assurance & Security, and Product & Strategy.
- **Governance Rules (`7` rules):** Protocol suite spanning Reading & Context Shielding (`00`), Versioning (`01`), Dual-Loop Spec-First Inquiry Gates (`02`), Ponytail 7-Rung Restraint (`03`), Micro-Modularity Law & R-41 Anti-Slop (`04`), Parallel Swarm Dispatch (`05`), and master Quad-Loop coordination (`AGENTS.md`).
- **Lifecycle Hooks (`4` hook modules in `hooks.json`):** `PreToolUse` destructive command firewall (`hooks/validate-tool-call.mjs`), `PostToolUse` Harness² feedback hook (`hooks/harness-post-tool.mjs`), `SessionStart` bootstrap (`hooks/session-start.mjs`), and `PreInvocation`/`Stop` chain reset (`hooks/reset-tool-chain.mjs`).
- **Core Frameworks:** Harness² error-driven self-learning (`Propose-Probe-Compose`), Ponytail 7-Rung Engineering Restraint, and Carpati 2-Layer Memory (`L0` working cache, `L1` immutable raw vault, `L2` compiled wiki).
- **Verification & OSS Governance:** Automated test suites (`tests/agi-manifest.test.mjs`, `tests/tool-chain-hooks.test.mjs`), audit/triage scripts (`scripts/`), `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, and dual-OS GitHub Actions CI/release workflows.

[1.0.1]: https://github.com/LoveBitterMuffin/agi/releases/tag/v1.0.1
[1.0.0]: https://github.com/LoveBitterMuffin/agi/releases/tag/v1.0.0
