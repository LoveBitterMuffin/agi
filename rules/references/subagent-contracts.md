# Subagent Dispatching & Delegation Contracts

## 1. Dispatch Template Schema
When invoking a subagent, format the prompt according to this contract:

```markdown
Role: [Role Name]
Objective: [1-2 sentences stating the specific deliverable]

Scope & Constraints:
- Read files: [explicit list of paths]
- Modifiable files: [explicit list of paths]
- Read limits: Never read files >250 lines in full; use StartLine/EndLine.

Action Checklist:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Deliverable Schema:
- Block 1: [Result summary]
- Block 2: [Status / artifacts]
- Confirmation of completion.
```

## 2. Standard Roles
- **Context Keeper (`context-keeper`):** Handles memory briefing (`/wiki-brief`), raw ingestion (`/wiki-ingest`), and SemVer releases (`/release-audit`).
- **Research Agent (`research`):** Read-only codebase and web exploration without state modifications.
- **Implementer (`self`):** Isolated implementation of tested components and code refactoring.
