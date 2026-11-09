---
trigger: always_on
description: Context hygiene, terminal output shielding, subagent firewalls, and file reading restrictions.
---

# 00: Reading Protocol, Context Shielding & Anti-Bloat Defense

## 1. File Inspection & Strict Range Reading
- **Hard Ban on Full Reads:** Never read files in `src/**`, `memory/raw/**`, or any file exceeding **250 lines** in its entirety.
- **Structural Mapping First:** Use symbol outline tools (`view_file_outline`) to map signatures and topology before reading logic.
- **Strict Range Reading:** Access implementation code strictly via targeted range reads (`read_file` with explicit `StartLine` and `EndLine`). Unbounded full reads of large files are strictly prohibited.

## 2. Terminal Output Shielding & Scratch-to-Disk (Log Clamping)
- **Zero Raw Console Dumps:** Never allow tests, builds, package installations, or directory tree scans (`Get-ChildItem -Recurse`, `npm test`, `pytest`) to dump hundreds of lines of stdout/stderr into the conversation context.
- **Scratch-to-Disk Redirection:** All verbose commands must redirect raw output to disk (`scratch/<cmd>.log` or via `.agents/scripts/run-shielded.ps1`).
- **High-Signal Return:** The tool response returned to the LLM must contain strictly:
  1. Exit code (0 or non-zero).
  2. Execution duration.
  3. A concise summary or the failing error stack slice (maximum 15 lines).

## 3. Subagent-First Doctrine & Episodic Context Firewalls
- **Subagents by Default (High-Priority Delegation):** The Lead is strictly an orchestrator, NOT a laborer. For any coding, testing, codebase exploration, or documentation task, the Lead MUST delegate to subagents (`invoke_subagent` using `TypeName: "self"` with specialized `Role`, or custom registered types) rather than accumulating tool calls in the parent thread.
- **Monolithic Context Saturation Ban:** Executing multi-command runs, raw file explorations, full test suites, or multi-file coding in the main thread is strictly forbidden. The Lead thread MUST NOT execute more than 5 tool calls in a sequence without delegating to a subagent or presenting findings to the user.
- **Episodic Sandbox Disposal:** Subagents execute intermediate commands and file edits within isolated, fresh contexts. Upon completion, they return only a compact 10-15 line summary to the parent agent. All intermediate tool logs and token bloat are discarded, keeping parent context ultra-lean (<15,000 tokens).

## 4. State Offloading, Memory Extraction & Rolling Compaction
- **Task Memory Retrieval (Выжимка):** Upon receiving a task, the agent MUST immediately inspect workspace `./memory/` and extract active context via `.agents/scripts/get-memory-brief.ps1` or targeted range reads of `memory/logs/ActiveSprintLog.md` and matching chapters in `memory/wiki/chapters/`.
- **Docs-as-Code as Persistent RAM:** Intermediate thinking, architectural specs, and findings must be written to disk (`memory/wiki/`, `memory/raw/vault/`, `memory/logs/ActiveSprintLog.md`), never held solely in chat transcript memory.
- **Compaction Checkpoint:** When a milestone is completed, the agent must commit state to Git and utilize `/compact` to reset the active context window back to the lean baseline (<15,000 tokens).

## 5. Navigation References
- Root Documentation Index: [Index](file:///./memory/Index.md)
- Navigation Hub: [MOC](file:///./memory/MOC.md)
- Sprint State & Active Tasks: [ActiveSprintLog](file:///./memory/logs/ActiveSprintLog.md)
- Release History: [CHANGELOG](file:///./memory/logs/CHANGELOG.md)
