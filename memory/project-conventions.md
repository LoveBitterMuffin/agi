---
type: project
created: 2026-05-25
updated: 2026-11-10
---

# Project Conventions

## Git Workflow
- Always create a new dedicated branch for major code changes.
- Branch name format should follow: `feature/[task-slug]` or `fix/[bug-slug]`.

## Supported AI platforms (AG Kit)
- AG Kit **only supports Gemini CLI and Google Antigravity**.
- Do not claim compatibility with Claude Code, Cursor, Copilot, Windsurf, or other assistants unless the user explicitly expands scope.
- Copy on the website, docs, FAQ, README, and marketing should describe AG Kit as a toolkit for Gemini CLI / Antigravity-style agent setups.

## Security Standards & Command Validation
- **UTF-16LE Base64 Security Decoder**: Pre-execution hooks must intercept all PowerShell Base64 encoded execution flags (`-EncodedCommand`, `-enc`, `-e`, `-ec`). The payload is normalized by decoding UTF-16LE bytes and recursively validating the underlying command against the destructive command blacklist.
- **Interpreter Root Protection**: Prohibit arbitrary execution scripts in `node -e`/`node --eval` and `python -c` that attempt to delete or alter filesystem drive roots (`C:\`, `D:\`, `E:\`, `/`).

## Universal Multi-Stack Test Harness
- The test harness (`harness/run-harness.ps1`) must remain platform- and project-agnostic with zero hardcoded legacy paths.
- **Multi-Stack Auto-Detection Order**:
  1. **Python**: Detects `pytest.ini`, `pyproject.toml`, or `tests/*.py` -> executes `pytest`.
  2. **Node.js**: Detects `package.json` -> executes `npm test` or `node --test`.
  3. **Rust**: Detects `Cargo.toml` -> executes `cargo test`.
  4. **Go**: Detects `go.mod` -> executes `go test ./...`.
