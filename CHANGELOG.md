# Changelog

All notable changes to the **AGI** (`antigravity-unified-core`) plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-11-10

### Added
- **Universal Multi-Stack Test Detector**: Added cross-platform auto-detection for Python (`pytest`), Node.js (`npm test`, `node --test`), Rust (`cargo test`), and Go (`go test ./...`) in `harness/run-harness.ps1`.
- **E2E Test Suites**: Added comprehensive unit and regression tests in `tests/harness-detector.test.mjs` and expanded `tests/security-and-registry.test.mjs`, expanding total automated test coverage to 32 tests.
- **Project Documentation**: Documented UTF-16LE Base64 security decoding and universal test harness standards in `memory/project-conventions.md`.

### Changed
- **Autonomous Orchestration Unchained**: Standardized default support for `ANTIGRAVITY_MAX_CHAIN_CALLS=unlimited` allowing autonomous multi-step orchestration without false tool-chain stalls.
- **Harness Modernization**: Purged legacy project dependencies and hardcoded paths from `harness/run-harness.ps1`.

### Fixed
- **PowerShell Encoded Command Bypass**: Fixed regex and decoding pipeline to detect UTF-16LE Base64-encoded command flags (`-EncodedCommand`, `-enc`, `-e`) in pre-command validation.
- **Drive Root Deletion Prevention**: Blocked destructive root deletion attempts via `node -e` / `node --eval` and `python -c`.

### Security
- **Multi-Engine Destructive Command Shield**: Enforced UTF-16LE Base64 decoding inspection in `hooks/tool-chain-hooks.mjs` and `hooks/command-guard.mjs` before passing commands to PowerShell and shells, preventing evasive destructive payloads.
- **Drive Boundary Isolation**: Prohibited destructive disk operations targeting filesystem roots (`C:\`, `D:\`, `E:\`, `/`) across Windows and Linux environments.

---

## [1.0.1] - 2026-11-09

### Added
- **Carpati 2-Layer Memory Architecture**: Structured L0/L1/L2 memory model with clamped active brief (`<=35` lines), wiki chapters, and immutable raw vault.
- **Dual-Loop Decision Model**: Interactive Gate 0 inquiry pre-selection and Gate 1 formal specification sign-off.
- **Ponytail 7-Rung Restraint**: Anti-bloat engineering doctrine enforcing code minimalism, stdlib preference, and anti-slop rules.
- **24-Agent SDLC Specialist Roster**: Comprehensive specialist agent configurations across UI/UX, core engineering, QA, resilience, and product strategy.
- **Quad-Loop Execution Telemetry**: Real-time telemetry guard verifying four-loop state transitions and hook lifecycles.

### Changed
- Refactored session start and tool chain monitoring hooks to ensure deterministic memory gates and tool limits.

### Fixed
- Handled edge cases in turn transcript inspection and PowerShell multi-BOM parsing.

### Security
- Baseline destructive command protection blocking `rm -rf`, disk wipes, and unauthorized format commands.
