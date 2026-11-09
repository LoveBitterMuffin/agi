---
name: release-audit
description: Verify git diff against wiki docs, bump SemVer versions, update CHANGELOG, and compact logs.
---
1. Run `git diff` on modified `src/` files.
2. Synchronize wiki chapter contents and line pointers with real code changes.
3. Calculate SemVer bump (MAJOR/MINOR/PATCH), set chapter status to `active`, update `memory/Index.md`.
4. Append release record to `memory/logs/CHANGELOG.md`.
5. Compact `memory/logs/ActiveSprintLog.md` if >180 lines.
