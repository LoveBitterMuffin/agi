# Security Policy

## Supported Versions

| Version | Supported |
| :--- | :--- |
| `1.0.x` | Yes |

## Reporting a Vulnerability

Please **do not** disclose security vulnerabilities in public GitHub issues or pull requests for `LoveBitterMuffin/agi`.

To report a vulnerability privately:

1. Open a private report via **GitHub Security Advisories** at `https://github.com/LoveBitterMuffin/agi/security/advisories/new`, or contact the maintainer directly via `https://github.com/LoveBitterMuffin`.
2. Provide the affected file(s), hook or script path, minimal reproduction steps, and potential security impact.
3. Allow reasonable time for triage, remediation, and coordinated disclosure before any public announcement.

Maintainers aim to acknowledge private reports within 48 hours.

## Scope of `PreToolUse` Destructive Command Firewall

`hooks.json` registers `hooks/validate-tool-call.mjs` on `PreToolUse` events for `run_command` and `invoke_subagent` (with a 10-second timeout).

- **In Scope:** Inspecting incoming tool-call payloads prior to execution, rejecting known destructive shell commands (such as `rm -rf /` and `format C:`), and enforcing tool-chain safety state checks.
- **Security Boundary:** `PreToolUse` acts as a deterministic defense-in-depth guardrail within the Antigravity agent runtime. It mitigates accidental or prompt-induced destructive actions, but it is **not** a substitute for OS-level sandboxing, container isolation, or least-privilege host permissions.

## Privacy & Zero-Secret Guarantee

- **Zero Telemetry:** This plugin collects and transmits no analytics, usage telemetry, or tracking pings.
- **Zero Bundled Credentials:** No API keys, OAuth secrets, passwords, or private tokens are stored in the repository. `.env` and `.env.*` files are excluded via `.gitignore`.
- **Local Runtime State:** Hook chain state, scratch logs (`scratch/`), and incident logs (`memory/harness_incidents.json`) stay strictly local to the host environment.
